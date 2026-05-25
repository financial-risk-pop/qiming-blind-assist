package com.blindassist.blind_assist_app.channels

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorManager
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 传感器 Platform Channel
 * 
 * 主要提供 Flutter 插件无法直接获取的高级传感器能力，目前包括：
 * - 查询设备是否具备某类传感器
 * - 获取传感器详细参数（精度、分辨率等）
 * 
 * 实时传感器数据的读取由 sensors_plus / geolocator 等 Flutter 插件负责。
 * 
 * Channel 名称：com.blindassist/sensors
 */
class SensorChannel(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "SensorChannel"
        private const val CHANNEL_NAME = "com.blindassist/sensors"
    }

    private val channel = MethodChannel(messenger, CHANNEL_NAME)
    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    init {
        channel.setMethodCallHandler(this)
        Log.i(TAG, "SensorChannel 已注册")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getAvailableSensors" -> {
                val sensors = listAvailableSensors()
                result.success(sensors)
            }
            "hasSensor" -> {
                val type = call.argument<String>("type") ?: ""
                result.success(hasSensor(type))
            }
            "getSensorInfo" -> {
                val type = call.argument<String>("type") ?: ""
                result.success(getSensorInfo(type))
            }
            else -> result.notImplemented()
        }
    }

    private fun listAvailableSensors(): List<Map<String, Any?>> {
        val sensors = sensorManager.getSensorList(Sensor.TYPE_ALL)
        return sensors.map { sensor ->
            mapOf(
                "name" to sensor.name,
                "type" to sensor.type,
                "typeName" to sensorTypeName(sensor.type),
                "vendor" to sensor.vendor,
                "maxRange" to sensor.maximumRange,
                "resolution" to sensor.resolution,
                "power" to sensor.power
            )
        }
    }

    private fun hasSensor(type: String): Boolean {
        val sensorType = mapTypeNameToInt(type) ?: return false
        return sensorManager.getDefaultSensor(sensorType) != null
    }

    private fun getSensorInfo(type: String): Map<String, Any?>? {
        val sensorType = mapTypeNameToInt(type) ?: return null
        val sensor = sensorManager.getDefaultSensor(sensorType) ?: return null
        return mapOf(
            "name" to sensor.name,
            "vendor" to sensor.vendor,
            "maxRange" to sensor.maximumRange,
            "resolution" to sensor.resolution,
            "power" to sensor.power,
            "minDelay" to sensor.minDelay
        )
    }

    private fun mapTypeNameToInt(type: String): Int? {
        return when (type.lowercase()) {
            "accelerometer" -> Sensor.TYPE_ACCELEROMETER
            "gyroscope" -> Sensor.TYPE_GYROSCOPE
            "magnetometer" -> Sensor.TYPE_MAGNETIC_FIELD
            "pressure" -> Sensor.TYPE_PRESSURE
            "light" -> Sensor.TYPE_LIGHT
            "proximity" -> Sensor.TYPE_PROXIMITY
            "step_counter" -> Sensor.TYPE_STEP_COUNTER
            "gravity" -> Sensor.TYPE_GRAVITY
            else -> null
        }
    }

    private fun sensorTypeName(type: Int): String {
        return when (type) {
            Sensor.TYPE_ACCELEROMETER -> "accelerometer"
            Sensor.TYPE_GYROSCOPE -> "gyroscope"
            Sensor.TYPE_MAGNETIC_FIELD -> "magnetometer"
            Sensor.TYPE_PRESSURE -> "pressure"
            Sensor.TYPE_LIGHT -> "light"
            Sensor.TYPE_PROXIMITY -> "proximity"
            Sensor.TYPE_STEP_COUNTER -> "step_counter"
            Sensor.TYPE_GRAVITY -> "gravity"
            else -> "unknown"
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
