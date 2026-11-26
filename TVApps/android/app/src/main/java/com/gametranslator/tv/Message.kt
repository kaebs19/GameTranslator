package com.gametranslator.tv

import org.json.JSONException
import org.json.JSONObject

/** What to draw. The phone sends the whole picture each time. */
data class Message(
    val lines: List<Line>, val isRtl: Boolean = true, val isTop: Boolean = true, val size: String = "medium",
) {
    data class Line(val text: String, val original: String?)

    companion object {
        /** `null` for a ping or anything unknown. */
        fun parse(json: String): Message? = try {
            val root = JSONObject(json)
            root.optJSONArray("lines")?.let { array ->
                val lines = (0 until array.length()).map { index ->
                    val line = array.getJSONObject(index)
                    Line(line.getString("text"), if (line.isNull("original")) null else line.getString("original"))
                }
                Message(
                    lines, root.optBoolean("isRTL"), root.optString("position") != "bottom", root.optString("size"),
                )
            }
        } catch (_: JSONException) {
            null
        }
    }
}
