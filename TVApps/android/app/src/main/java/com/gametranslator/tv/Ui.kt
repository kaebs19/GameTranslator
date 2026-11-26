package com.gametranslator.tv

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.TextView

/** The palette of the iPhone app. */
object Palette {
    val panel = Color.parseColor("#DB0A1020")
    val surface = Color.parseColor("#1D2743")
    val focus = Color.parseColor("#3D63F5")
    val accent = Color.parseColor("#9A8CFF")
    val text = Color.parseColor("#F4F6FF")
    val secondary = Color.parseColor("#A7B1CF")
    val warning = Color.parseColor("#FBBF24")
    val success = Color.parseColor("#34D399")
}

fun Context.dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

fun Context.label(size: Float, color: Int = Palette.text, text: CharSequence = "") = TextView(this).apply {
    this.text = text
    gravity = Gravity.CENTER
    setTextColor(color)
    setTextSize(TypedValue.COMPLEX_UNIT_SP, size)
}

/** The focused one must be obvious from across the room. */
fun Context.button(title: CharSequence, action: () -> Unit) = Button(this).apply {
    text = title
    isAllCaps = false
    setTextColor(Palette.text)
    setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
    stateListAnimator = null
    background = StateListDrawable().apply {
        addState(intArrayOf(android.R.attr.state_focused), rounded(Palette.focus, Palette.accent))
        addState(intArrayOf(), rounded(Palette.surface))
    }
    setOnClickListener { action() }
}

fun View.rounded(fill: Int, outline: Int? = null) = GradientDrawable().apply {
    setColor(fill)
    cornerRadius = context.dp(12).toFloat()
    if (outline != null) setStroke(context.dp(3), outline)
}
