package com.gametranslator.tv

/** Digits from the phone: where it is, then a PIN. Same rules as PairingCode.swift. */
data class PairingCode(val address: String, val pin: String) {
    companion object {
        private const val PIN_LENGTH = 4

        private class Range(val base: Long, val bits: Int, val digits: Int)

        private val ranges = mapOf(
            '1' to Range(0xC0A80000, 16, 5),
            '2' to Range(0xAC100000, 20, 7),
            '3' to Range(0x0A000000, 24, 8),
            '4' to Range(0, 32, 10),
        )

        /** `null` until the first digit says. */
        fun length(first: Char?): Int? = ranges[first]?.let { 1 + it.digits + PIN_LENGTH }

        fun decode(digits: String): PairingCode? {
            val range = ranges[digits.firstOrNull()] ?: return null
            if (digits.length != length(digits.first()) || digits.any { it !in '0'..'9' }) return null
            val host = digits.substring(1, 1 + range.digits).toLong()
            if (host >= 1L shl range.bits) return null
            val value = range.base + host
            val address = listOf(24, 16, 8, 0).joinToString(".") { (value shr it and 0xFF).toString() }
            return PairingCode(address, digits.takeLast(PIN_LENGTH))
        }
    }
}
