package com.gametranslator.tv

import android.content.Context
import android.os.Build
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * The paired phone, reached on the home network, or through the SubGG server when the phone's app
 * runs in the background. The token is kept in this app's private storage.
 */
data class Phone(val address: String, val token: String, val isServer: Boolean = false) {
    val events: URL get() = if (isServer) {
        URL("$SERVER/v1/tv/events?token=${URLEncoder.encode(token, "UTF-8")}")
    } else {
        URL("http://$address:$PORT/events?token=$token")
    }

    enum class PairingError { WRONG, LOCKED, UNREACHABLE }

    class PairingFailed(val error: PairingError) : Exception()

    companion object {
        private const val PORT = 8787
        private const val SERVER = "https://api.subgg.app"
        private const val TIMEOUT = 6_000

        private fun preferences(context: Context) = context.getSharedPreferences("phone", Context.MODE_PRIVATE)

        fun load(context: Context): Phone? = preferences(context).run {
            val address = getString("address", null) ?: return null
            Phone(address, getString("token", null) ?: return null, getBoolean("server", false))
        }

        fun save(context: Context, phone: Phone) = preferences(context).edit()
            .putString("address", phone.address).putString("token", phone.token).putBoolean("server", phone.isServer).apply()

        /** Blocks: call off the main thread. */
        @Throws(PairingFailed::class)
        fun pairWithServer(code: String): Phone {
            val connection = URL("$SERVER/v1/tv/pair").openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = TIMEOUT
                connection.readTimeout = TIMEOUT
                connection.doOutput = true
                connection.setRequestProperty("Content-Type", "application/json")
                val body = JSONObject().put("code", code).put("name", "${Build.MANUFACTURER} ${Build.MODEL}")
                connection.outputStream.use { it.write(body.toString().toByteArray()) }
                when (connection.responseCode) {
                    200 -> {
                        val answer = connection.inputStream.bufferedReader().use { it.readText() }
                        return Phone("api.subgg.app", JSONObject(answer).getString("token"), isServer = true)
                    }
                    429 -> throw PairingFailed(PairingError.LOCKED)
                    else -> throw PairingFailed(PairingError.WRONG)
                }
            } catch (_: IOException) {
                throw PairingFailed(PairingError.UNREACHABLE)
            } catch (_: JSONException) {
                throw PairingFailed(PairingError.UNREACHABLE)
            } finally {
                connection.disconnect()
            }
        }

        fun forget(context: Context) = preferences(context).edit().clear().apply()

        /** Blocks: call off the main thread. */
        @Throws(PairingFailed::class)
        fun pair(code: PairingCode): Phone {
            val connection = URL("http://${code.address}:$PORT/pair").openConnection() as HttpURLConnection
            try {
                connection.connectTimeout = TIMEOUT
                connection.readTimeout = TIMEOUT
                connection.doOutput = true
                val body = JSONObject().put("pin", code.pin).put("name", "${Build.MANUFACTURER} ${Build.MODEL}")
                connection.outputStream.use { it.write(body.toString().toByteArray()) }
                when (connection.responseCode) {
                    200 -> {
                        val answer = connection.inputStream.bufferedReader().use { it.readText() }
                        return Phone(code.address, JSONObject(answer).getString("token"))
                    }
                    429 -> throw PairingFailed(PairingError.LOCKED)
                    else -> throw PairingFailed(PairingError.WRONG)
                }
            } catch (_: IOException) {
                throw PairingFailed(PairingError.UNREACHABLE)
            } catch (_: JSONException) {
                throw PairingFailed(PairingError.UNREACHABLE)
            } finally {
                connection.disconnect()
            }
        }
    }
}
