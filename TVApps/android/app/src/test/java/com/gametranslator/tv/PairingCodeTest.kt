package com.gametranslator.tv

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The same examples as PairingCodeTests.swift. */
class PairingCodeTest {
    @Test fun decodesEveryRange() {
        mapOf(
            "1003054821" to "192.168.1.49", "1655354821" to "192.168.255.255", "202647054821" to "172.20.10.1",
            "3000000074821" to "10.0.0.7", "416819159054821" to "100.64.0.1",
        ).forEach { (digits, address) ->
            assertEquals(PairingCode(address, "4821"), PairingCode.decode(digits))
        }
    }

    @Test fun refusesOtherDigits() {
        listOf("", "1", "0003054821", "5003054821", "100305482", "10030548211", "1999994821", "1abcde4821")
            .forEach { assertNull(PairingCode.decode(it)) }
    }
}
