package com.gametranslator.tv

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import kotlin.concurrent.thread

/** Pairing, the overlay permission, then start and stop. */
class MainActivity : Activity() {
    private enum class Screen { PAIR, PERMISSION, READY }

    private var screen: Screen? = null
    private var digits = ""
    private var isPairing = false
    private var digitsLabel: TextView? = null
    private var message: TextView? = null
    /** The TV has no settings page for the permission. */
    private var needsComputer = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        refresh()
    }

    override fun onResume() {
        super.onResume()
        OverlayService.onStateChange = { refresh() }
        refresh()
    }

    override fun onPause() {
        OverlayService.onStateChange = null
        super.onPause()
    }

    private fun refresh() {
        val next = when {
            Phone.load(this) == null -> Screen.PAIR
            !Settings.canDrawOverlays(this) -> Screen.PERMISSION
            else -> Screen.READY
        }
        // Typed digits and focus survive unless the screen really changes.
        if (next == screen && next == Screen.PAIR) return
        screen = next
        setContentView(
            when (next) {
                Screen.PAIR -> pairScreen()
                Screen.PERMISSION -> permissionScreen()
                Screen.READY -> readyScreen()
            }
        )
    }

    private fun column(build: LinearLayout.() -> Unit) = LinearLayout(this).apply {
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setPadding(dp(48), dp(24), dp(48), dp(24))
        build()
    }

    private fun LinearLayout.addSpaced(view: View, width: Int = LinearLayout.LayoutParams.WRAP_CONTENT) {
        addView(view, LinearLayout.LayoutParams(width, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
            setMargins(0, dp(6), 0, dp(6))
        })
    }

    // Pairing

    private fun pairScreen() = column {
        addSpaced(label(28f, text = getString(R.string.app_name)))
        addSpaced(label(18f, Palette.secondary, getString(R.string.pair_help)))
        digitsLabel = label(36f, Palette.accent).apply {
            letterSpacing = 0.12f
            textDirection = View.TEXT_DIRECTION_LTR
        }.also { addSpaced(it) }
        message = label(18f, Palette.warning).also { addSpaced(it) }
        addSpaced(keypad())
        drawDigits()
    }

    private fun keypad() = GridLayout(this).apply {
        columnCount = 3
        layoutDirection = View.LAYOUT_DIRECTION_LTR
        for (key in listOf("1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫")) {
            val view = if (key == "⌫") button(getString(R.string.delete), ::deleteDigit) else button(key) { addDigit(key) }
            if (key.isEmpty()) view.visibility = View.INVISIBLE
            if (key == "1") view.post { view.requestFocus() }
            addView(view, GridLayout.LayoutParams().apply {
                width = dp(96)
                height = dp(48)
                setMargins(dp(4), dp(4), dp(4), dp(4))
            })
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (screen == Screen.PAIR) {
            if (keyCode in KeyEvent.KEYCODE_0..KeyEvent.KEYCODE_9) {
                addDigit((keyCode - KeyEvent.KEYCODE_0).toString())
                return true
            }
            if (keyCode == KeyEvent.KEYCODE_DEL || (keyCode == KeyEvent.KEYCODE_BACK && digits.isNotEmpty())) {
                deleteDigit()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun addDigit(digit: String) {
        if (isPairing) return
        if (digits.isEmpty()) message?.text = ""
        val length = PairingCode.length((digits + digit).first()) ?: return
        digits += digit
        drawDigits()
        if (digits.length == length) submit()
    }

    private fun deleteDigit() {
        if (isPairing) return
        digits = digits.dropLast(1)
        drawDigits()
    }

    private fun drawDigits() {
        digitsLabel?.text = digits.padEnd(minOf(PairingCode.length(digits.firstOrNull()) ?: 10, 10), '–')
    }

    private fun submit() {
        val code = PairingCode.decode(digits) ?: return failed(R.string.pair_wrong)
        isPairing = true
        message?.setText(R.string.pair_connecting)
        thread {
            try {
                val phone = Phone.pair(code)
                runOnUiThread { paired(phone) }
            } catch (failure: Phone.PairingFailed) {
                val text = when (failure.error) {
                    Phone.PairingError.WRONG -> R.string.pair_wrong
                    Phone.PairingError.LOCKED -> R.string.pair_locked
                    Phone.PairingError.UNREACHABLE -> R.string.pair_unreachable
                }
                runOnUiThread { failed(text) }
            }
        }
    }

    private fun failed(text: Int) {
        isPairing = false
        digits = ""
        drawDigits()
        message?.setText(text)
    }

    private fun paired(phone: Phone) {
        isPairing = false
        digits = ""
        Phone.save(applicationContext, phone)
        if (isDestroyed) return
        if (Settings.canDrawOverlays(this)) OverlayService.start(this)
        refresh()
    }

    // Permission

    private fun permissionScreen() = column {
        addSpaced(label(28f, text = getString(R.string.app_name)))
        val text = if (needsComputer) getString(R.string.permission_manual, ADB_COMMAND) else getString(R.string.permission_help)
        addSpaced(label(20f, Palette.secondary, text))
        addSpaced(button(getString(R.string.permission_button), ::openPermission).focused(), dp(320))
        addSpaced(button(getString(R.string.pair_again), ::pairAgain), dp(320))
    }

    private fun openPermission() {
        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            needsComputer = true
            refresh()
        }
    }

    // Ready

    private fun readyScreen() = column {
        val isRunning = OverlayService.isRunning
        addSpaced(label(28f, text = getString(R.string.app_name)))
        if (isRunning) {
            val isConnected = OverlayService.isConnected
            addSpaced(
                label(
                    20f, if (isConnected) Palette.success else Palette.warning,
                    getString(if (isConnected) R.string.state_connected else R.string.state_waiting),
                )
            )
        }
        addSpaced(label(18f, Palette.secondary, getString(R.string.ready_help)))
        if (isRunning) {
            addSpaced(button(getString(R.string.close)) { moveTaskToBack(true) }.focused(), dp(320))
            addSpaced(button(getString(R.string.test)) { OverlayService.start(context, isTest = true) }, dp(320))
            addSpaced(button(getString(R.string.stop)) { OverlayService.stop(context) }, dp(320))
        } else {
            addSpaced(button(getString(R.string.start)) { OverlayService.start(context) }.focused(), dp(320))
        }
        addSpaced(button(getString(R.string.pair_again), ::pairAgain), dp(320))
    }

    private fun pairAgain() {
        OverlayService.stop(this)
        Phone.forget(this)
        refresh()
    }

    private fun View.focused(): View = apply { post { requestFocus() } }

    private companion object {
        const val ADB_COMMAND = "adb shell appops set com.gametranslator.tv SYSTEM_ALERT_WINDOW allow"
    }
}
