package com.gametranslator.tv

import android.content.Context
import android.graphics.Typeface
import android.view.View
import android.widget.LinearLayout

/** Translated lines on a dark panel. */
class OverlayView(context: Context) : LinearLayout(context) {
    init {
        orientation = VERTICAL
        background = rounded(Palette.panel)
        setPadding(context.dp(20), context.dp(8), context.dp(20), context.dp(8))
        visibility = View.GONE
    }

    fun show(message: Message) {
        removeAllViews()
        layoutDirection = if (message.isRtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
        val size = when (message.size) {
            "small" -> 20f
            "large" -> 36f
            else -> 27f
        }
        for (line in message.lines) {
            addView(row(size, Palette.text, line.text).apply { typeface = Typeface.DEFAULT_BOLD })
            line.original?.let { addView(row(size * 0.62f, Palette.secondary, it)) }
        }
        visibility = if (message.lines.isEmpty()) View.GONE else View.VISIBLE
    }

    /** Long lines wrap before the edges, which some TVs cut off. */
    private fun row(size: Float, color: Int, text: String) = context.label(size, color, text).apply {
        maxWidth = resources.displayMetrics.widthPixels * 8 / 10
        textDirection = View.TEXT_DIRECTION_FIRST_STRONG
    }
}
