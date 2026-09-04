package com.example.krishi_rakshak_app

import android.os.Bundle
import android.speech.tts.TextToSpeech
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity(), TextToSpeech.OnInitListener {
    private val channelName = "krishi_rakshak/voice"
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        tts = TextToSpeech(this, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "speak" -> {
                        val text = call.argument<String>("text") ?: ""
                        val language = call.argument<String>("language") ?: "en"

                        if (!ttsReady || text.isBlank()) {
                            result.error("TTS_NOT_READY", "Text-to-Speech is not ready.", null)
                            return@setMethodCallHandler
                        }

                        val locale = localeForLanguage(language)
                        val availability = tts?.isLanguageAvailable(locale) ?: TextToSpeech.LANG_NOT_SUPPORTED

                        if (availability == TextToSpeech.LANG_NOT_SUPPORTED ||
                            availability == TextToSpeech.LANG_MISSING_DATA
                        ) {
                            result.error("LANGUAGE_NOT_AVAILABLE", "Voice language is not installed.", null)
                            return@setMethodCallHandler
                        }

                        tts?.language = locale
                        tts?.setSpeechRate(0.92f)
                        tts?.setPitch(1.0f)
                        tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "krishi_rakshak_answer")
                        result.success(true)
                    }

                    "stop" -> {
                        tts?.stop()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onInit(status: Int) {
        ttsReady = status == TextToSpeech.SUCCESS
    }

    private fun localeForLanguage(language: String): Locale {
        return when (language) {
            "hi" -> Locale("hi", "IN")
            "pa" -> Locale("pa", "IN")
            "mr" -> Locale("mr", "IN")
            "bn" -> Locale("bn", "IN")
            "gu" -> Locale("gu", "IN")
            "ta" -> Locale("ta", "IN")
            "te" -> Locale("te", "IN")
            "kn" -> Locale("kn", "IN")
            "ml" -> Locale("ml", "IN")
            else -> Locale.US
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }
}
