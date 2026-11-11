package com.spymusic.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.audiofx.AudioEffect
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import androidx.annotation.Keep

@Keep
class Equalizer {
    fun openEqualizer(sessionId: Int, context: Context, activity: Activity): Boolean {
        val intent = Intent(AudioEffect.ACTION_DISPLAY_AUDIO_EFFECT_CONTROL_PANEL).apply {
            putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.packageName)
            putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
            putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
        }
        if ((intent.resolveActivity(context.packageManager) != null)) {
            activity.startActivityForResult(intent, 0)
            return true
        } else {
            if (!openManufacturerEqualizer(sessionId, context, activity)) {
                // If no equalizer app is found, open system sound settings as a last resort
                return openSoundSettings(activity)
            }
            return true
        }
    }

    fun initAudioEffect(sessionId: Int, context: Context) {
        sendAudioEffectIntent(
            sessionId,
            AudioEffect.ACTION_OPEN_AUDIO_EFFECT_CONTROL_SESSION,
            context
        )
        applyLoudnessBoost(sessionId)
        println("Sent AudioEffect intent for opening")
    }

    fun endAudioEffect(sessionId: Int, context: Context) {
        sendAudioEffectIntent(
            sessionId,
            AudioEffect.ACTION_CLOSE_AUDIO_EFFECT_CONTROL_SESSION,
            context
        )
        println("Sent AudioEffect intent for closure")
    }

    private fun sendAudioEffectIntent(sessionId: Int, action: String, context: Context) {
        val intent = Intent(action).apply {
            putExtra(AudioEffect.EXTRA_PACKAGE_NAME, context.packageName)
            putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
            putExtra(AudioEffect.EXTRA_CONTENT_TYPE, AudioEffect.CONTENT_TYPE_MUSIC)
            addFlags(Intent.FLAG_INCLUDE_STOPPED_PACKAGES)
        }
        context.sendBroadcast(intent)
    }

    private fun openManufacturerEqualizer(
        sessionId: Int,
        context: Context,
        activity: Activity
    ): Boolean {
        val equalizerPackages = listOf(
            "com.android.settings.Settings\$SoundSettingsActivity", // Generic Android
            "com.android.settings.EqualizerSettings",
            "com.samsung.android.soundalive", // Samsung
            "com.miui.audioeffect", // Xiaomi
            "com.oneplus.sound.tuner" // OnePlus
        )

        for (packageName in equalizerPackages) {
            try {
                val intent = context.packageManager.getLaunchIntentForPackage(packageName)
                if (intent != null) {
                    intent.putExtra(AudioEffect.EXTRA_AUDIO_SESSION, sessionId)
                    intent.putExtra(AudioEffect.EXTRA_PACKAGE_NAME, packageName)
                    activity.startActivity(intent)
                    return true
                }
            } catch (_: Exception) {

            }
        }
        return false
    }

    private fun openSoundSettings(activity: Activity): Boolean {
        try {
            activity.startActivity(Intent(android.provider.Settings.ACTION_SOUND_SETTINGS))
            return true
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return false
    }

    companion object {
        // +2.5 dB (250 mB) (~33% linear amplitude / ~25% perceived loudness boost)
        // using Android's native LoudnessEnhancer compressor/limiter so peaks
        // stay clean without clipping or distortion.
        private const val DEFAULT_LOUDNESS_BOOST_MB = 250
        private val loudnessLock = Any()
        private var loudnessEnhancer: LoudnessEnhancer? = null
        private var loudnessSessionId: Int = AudioEffect.ERROR_BAD_VALUE

        private fun applyLoudnessBoost(sessionId: Int) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.KITKAT || sessionId <= 0) {
                return
            }
            synchronized(loudnessLock) {
                try {
                    val existing = loudnessEnhancer
                    if (existing != null && loudnessSessionId == sessionId) {
                        existing.setTargetGain(DEFAULT_LOUDNESS_BOOST_MB)
                        existing.setEnabled(true)
                        return
                    }
                    releaseLoudnessBoostLocked()
                    val enhancer = LoudnessEnhancer(sessionId).apply {
                        setTargetGain(DEFAULT_LOUDNESS_BOOST_MB)
                        setEnabled(true)
                    }
                    loudnessEnhancer = enhancer
                    loudnessSessionId = sessionId
                } catch (t: Throwable) {
                    t.printStackTrace()
                    releaseLoudnessBoostLocked()
                }
            }
        }

        private fun releaseLoudnessBoostLocked() {
            try {
                loudnessEnhancer?.setEnabled(false)
            } catch (_: Throwable) {
            }
            try {
                loudnessEnhancer?.release()
            } catch (_: Throwable) {
            }
            loudnessEnhancer = null
            loudnessSessionId = AudioEffect.ERROR_BAD_VALUE
        }
    }
}