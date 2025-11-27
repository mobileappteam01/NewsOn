package com.app.newson

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class DynamicIconPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private var context: android.content.Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.app.newson/dynamic_icon")
        channel.setMethodCallHandler(this)
        context = flutterPluginBinding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "changeIcon" -> {
                val iconName = call.argument<String>("iconName") ?: "default"
                changeIcon(iconName, result)
            }
            "getCurrentIcon" -> {
                getCurrentIcon(result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun changeIcon(iconName: String, result: MethodChannel.Result) {
        val pm = context?.packageManager ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        val packageName = context?.packageName ?: run {
            result.error("NO_PACKAGE", "Package name not available", null)
            return
        }

        try {
            // Disable all aliases first to ensure only one is active
            disableComponent(pm, packageName, "$packageName.MainActivityDefault")
            disableComponent(pm, packageName, "$packageName.MainActivityDynamic1")
            disableComponent(pm, packageName, "$packageName.MainActivityDynamic2")

            // Enable the selected alias
            when (iconName) {
                "default" -> {
                    enableComponent(pm, packageName, "$packageName.MainActivityDefault")
                }
                "dynamic1" -> {
                    enableComponent(pm, packageName, "$packageName.MainActivityDynamic1")
                }
                "dynamic2" -> {
                    enableComponent(pm, packageName, "$packageName.MainActivityDynamic2")
                }
                else -> {
                    // Default to MainActivityDefault if unknown icon name
                    enableComponent(pm, packageName, "$packageName.MainActivityDefault")
                }
            }

            result.success(true)
        } catch (e: Exception) {
            result.error("ICON_CHANGE_ERROR", "Failed to change icon: ${e.message}", null)
        }
    }

    private fun getCurrentIcon(result: MethodChannel.Result) {
        val pm = context?.packageManager ?: run {
            result.error("NO_CONTEXT", "Context not available", null)
            return
        }

        val packageName = context?.packageName ?: run {
            result.error("NO_PACKAGE", "Package name not available", null)
            return
        }

        try {
            val defaultState = pm.getComponentEnabledSetting(
                ComponentName(packageName, "$packageName.MainActivityDefault")
            )
            val dynamic1State = pm.getComponentEnabledSetting(
                ComponentName(packageName, "$packageName.MainActivityDynamic1")
            )
            val dynamic2State = pm.getComponentEnabledSetting(
                ComponentName(packageName, "$packageName.MainActivityDynamic2")
            )

            when {
                defaultState == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> result.success("default")
                dynamic1State == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> result.success("dynamic1")
                dynamic2State == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> result.success("dynamic2")
                else -> result.success("default")
            }
        } catch (e: Exception) {
            result.error("GET_ICON_ERROR", "Failed to get current icon: ${e.message}", null)
        }
    }

    private fun enableComponent(pm: PackageManager, packageName: String, aliasName: String) {
        pm.setComponentEnabledSetting(
            ComponentName(packageName, aliasName),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun disableComponent(pm: PackageManager, packageName: String, aliasName: String) {
        pm.setComponentEnabledSetting(
            ComponentName(packageName, aliasName),
            PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}

