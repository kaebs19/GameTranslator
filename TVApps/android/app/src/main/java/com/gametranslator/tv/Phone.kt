package com.gametranslator.tv

import android.content.Context
import android.os.Build
import org.json.JSONException
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

/** The paired phone. The token is kept in this app's private storage. */
data class Phone(val address: String, val token: String) {
    val events get() = URL("http://$address:$PORT/events?token=$token")

    enum class PairingError { WRONG, LOCKED, UNREACHABLE }

    class PairingFailed(val error: PairingError) : Exception()

    companion object {
        private const val PORT = 8787
        private const val TIMEOUT = 6_000

        private fun preferences(context: Context) = context.getSharedPreferences("phone", Context.MODE_PRIVATE)

        fun load(context: Context): Phone? = preferences(context).run {
            val address = getString("address", null) ?: return null
            Phone(address, getString("token", null) ?: return null)
        }

        fun save(context: Context, phone: Phone) =
            preferences(context).edit().putString("address", phone.address).putString("token", phone.token).apply()

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
