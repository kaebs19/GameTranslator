package com.gametranslator.tv

import java.io.IOException
import java.net.HttpURLConnection
import kotlin.concurrent.thread

/** Keeps a connection to the phone and tries again whenever it drops. Callbacks come on its own thread. */
class PhoneStream(private val phone: Phone, private val listener: Listener) {
    interface Listener {
        fun onConnected(isConnected: Boolean)
        fun onMessage(message: Message)

        /** The phone removed this TV. */
        fun onRefused()
    }

    @Volatile private var isStopped = false
    @Volatile private var connection: HttpURLConnection? = null
    private val worker = thread(name = "PhoneStream", isDaemon = true) { run() }

    fun stop() {
        isStopped = true
        // Closing a socket is network work, which the main thread may not do.
        thread { connection?.disconnect() }
        worker.interrupt()
    }

    private fun run() {
        while (!isStopped) {
            try {
                if (!read()) return
            } catch (_: IOException) {
                // Out of reach: try again below.
            } finally {
                connection?.disconnect()
            }
            if (isStopped) return
            listener.onConnected(false)
            try {
                Thread.sleep(RETRY)
            } catch (_: InterruptedException) {
                return
            }
        }
    }

    /** Returns false when there is no point in trying again. */
    private fun read(): Boolean {
        val connection = phone.events.openConnection() as HttpURLConnection
        this.connection = connection
        connection.connectTimeout = SILENCE
        // The phone sends something every five seconds.
        connection.readTimeout = SILENCE
        connection.setRequestProperty("Accept", "text/event-stream")
        when (connection.responseCode) {
            200 -> Unit
            401 -> {
                if (!isStopped) listener.onRefused()
                return false
            }
            else -> return true
        }
        listener.onConnected(true)
        connection.inputStream.bufferedReader().use { reader ->
            while (!isStopped) {
                val line = reader.readLine() ?: break
                if (!line.startsWith(PREFIX)) continue
                val message = Message.parse(line.substring(PREFIX.length)) ?: continue
                if (!isStopped) listener.onMessage(message)
            }
        }
        return true
    }

    private companion object {
        const val PREFIX = "data: "
        const val SILENCE = 12_000
        const val RETRY = 3_000L
    }
}
