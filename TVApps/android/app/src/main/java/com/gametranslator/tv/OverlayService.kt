package com.gametranslator.tv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager

/** Draws translations over whatever the TV shows, for as long as the user leaves it on. */
class OverlayService : Service(), PhoneStream.Listener {
    private val main = Handler(Looper.getMainLooper())
    private val windows by lazy { getSystemService(Context.WINDOW_SERVICE) as WindowManager }
    private var overlay: OverlayView? = null
    private var stream: PhoneStream? = null
    private var isDestroyed = false
    private val endTest = Runnable { overlay?.show(current) }
    private var current = EMPTY

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        goForeground()
        val phone = Phone.load(this)
        if (phone == null || !Settings.canDrawOverlays(this)) return stopSelf()
        val view = OverlayView(this)
        windows.addView(view, layout(isTop = true))
        overlay = view
        isRunning = true
        stream = PhoneStream(phone, this)
        onStateChange?.invoke()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_TEST) {
            overlay?.show(Message(listOf(Message.Line(getString(R.string.test_line), null))))
            main.removeCallbacks(endTest)
            main.postDelayed(endTest, TEST_DURATION)
        }
        return if (overlay == null) START_NOT_STICKY else START_STICKY
    }

    override fun onDestroy() {
        isDestroyed = true
        stream?.stop()
        main.removeCallbacksAndMessages(null)
        overlay?.let(windows::removeView)
        overlay = null
        isRunning = false
        isConnected = false
        onStateChange?.invoke()
        super.onDestroy()
    }

    // PhoneStream calls from its own thread.

    override fun onConnected(isConnected: Boolean) = onMain {
        OverlayService.isConnected = isConnected
        // Old text must not stay over the game.
        if (!isConnected) show(EMPTY)
        onStateChange?.invoke()
    }

    override fun onMessage(message: Message) = onMain { show(message) }

    override fun onRefused() = onMain {
        Phone.forget(this)
        stopSelf()
    }

    private fun onMain(action: () -> Unit) {
        main.post { if (!isDestroyed) action() }
    }

    private fun show(message: Message) {
        val view = overlay ?: return
        if (message.isTop != current.isTop) windows.updateViewLayout(view, layout(message.isTop))
        current = message
        main.removeCallbacks(endTest)
        view.show(message)
    }

    private fun layout(isTop: Boolean) = WindowManager.LayoutParams(
        WindowManager.LayoutParams.WRAP_CONTENT, WindowManager.LayoutParams.WRAP_CONTENT,
        @Suppress("DEPRECATION")
        if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
        // The remote keeps controlling the game. Not FLAG_NOT_TOUCHABLE: Android 12 fades such windows,
        // and TVs have no touch to pass through.
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
        PixelFormat.TRANSLUCENT,
    ).apply {
        gravity = Gravity.CENTER_HORIZONTAL or (if (isTop) Gravity.TOP else Gravity.BOTTOM)
        y = resources.displayMetrics.heightPixels / 20
    }

    private fun goForeground() {
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, getString(R.string.app_name), NotificationManager.IMPORTANCE_LOW)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            Notification.Builder(this, CHANNEL)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = builder.setSmallIcon(android.R.drawable.ic_menu_view)
            .setContentTitle(getString(R.string.notification)).setContentIntent(open).setOngoing(true).build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(1, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(1, notification)
        }
    }

    companion object {
        private const val CHANNEL = "overlay"
        private const val ACTION_TEST = "test"
        private const val TEST_DURATION = 6_000L
        private val EMPTY = Message(emptyList())

        // Main thread only; the screen reads them.
        var isRunning = false
            private set
        var isConnected = false
            private set
        var onStateChange: (() -> Unit)? = null

        fun start(context: Context, isTest: Boolean = false) {
            val intent = Intent(context, OverlayService::class.java).setAction(if (isTest) ACTION_TEST else null)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }
    }
}
