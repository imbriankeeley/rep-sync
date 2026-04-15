package com.repsync.app.ui.components

import android.graphics.Paint
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.dp
import com.repsync.app.ui.theme.BackgroundCardElevated
import com.repsync.app.ui.theme.PrimaryGreen
import com.repsync.app.ui.theme.TextOnDarkSecondary
import com.repsync.app.util.formatWeightValue
import java.time.LocalDate
import java.time.format.DateTimeFormatter

data class ChartDataPoint(
    val date: LocalDate,
    val value: Double,
)

@Composable
fun WeightProgressionChart(
    dataPoints: List<ChartDataPoint>,
    modifier: Modifier = Modifier,
    lineColor: Color = PrimaryGreen,
    label: String = "",
) {
    if (dataPoints.isEmpty()) {
        Box(
            modifier = modifier
                .clip(RoundedCornerShape(12.dp))
                .background(BackgroundCardElevated)
                .padding(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "No data yet",
                color = TextOnDarkSecondary,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        return
    }

    if (dataPoints.size == 1) {
        Box(
            modifier = modifier
                .clip(RoundedCornerShape(12.dp))
                .background(BackgroundCardElevated)
                .padding(16.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = buildString {
                    append(formatChartValue(dataPoints.first().value, label))
                    if (label.isNotBlank()) {
                        append(" ")
                        append(label)
                    }
                },
                color = lineColor,
                style = MaterialTheme.typography.headlineMedium,
            )
        }
        return
    }

    val labelArgb = TextOnDarkSecondary.toArgb()
    val gridArgb = BackgroundCardElevated.toArgb()
    val dotColor = lineColor

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(BackgroundCardElevated),
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 12.dp, bottom = 28.dp, start = 44.dp, end = 12.dp),
        ) {
            val minVal = dataPoints.minOf { it.value }
            val maxVal = dataPoints.maxOf { it.value }
            val valueRange = if (maxVal == minVal) 10.0 else maxVal - minVal
            val paddedMin = minVal - valueRange * 0.1
            val paddedMax = maxVal + valueRange * 0.1
            val paddedRange = paddedMax - paddedMin

            val width = size.width
            val height = size.height

            val textPaint = Paint().apply {
                color = labelArgb
                textSize = 28f
                isAntiAlias = true
            }

            // Y-axis labels (min, mid, max)
            val yLabels = listOf(paddedMin, (paddedMin + paddedMax) / 2, paddedMax)
            yLabels.forEach { value ->
                val y = height - ((value - paddedMin) / paddedRange * height).toFloat()
                // Grid line
                drawLine(
                    color = Color(gridArgb).copy(alpha = 0.3f),
                    start = Offset(0f, y),
                    end = Offset(width, y),
                    strokeWidth = 1f,
                )
                // Label
                drawContext.canvas.nativeCanvas.drawText(
                    formatChartValue(value, label),
                    -40f,
                    y + 10f,
                    textPaint,
                )
            }

            // Plot points
            val points = dataPoints.mapIndexed { index, point ->
                val x = if (dataPoints.size > 1) {
                    (index.toFloat() / (dataPoints.size - 1)) * width
                } else {
                    width / 2
                }
                val y = height - ((point.value - paddedMin) / paddedRange * height).toFloat()
                Offset(x, y)
            }

            // Draw line
            if (points.size >= 2) {
                val path = Path().apply {
                    moveTo(points.first().x, points.first().y)
                    for (i in 1 until points.size) {
                        lineTo(points[i].x, points[i].y)
                    }
                }
                drawPath(
                    path = path,
                    color = lineColor,
                    style = Stroke(width = 3f, cap = StrokeCap.Round),
                )
            }

            // Draw dots
            points.forEach { point ->
                drawCircle(
                    color = dotColor,
                    radius = 5f,
                    center = point,
                )
            }

            // X-axis date labels (first and last)
            val dateFormatter = DateTimeFormatter.ofPattern("M/d")
            val firstDateText = dataPoints.first().date.format(dateFormatter)
            val lastDateText = dataPoints.last().date.format(dateFormatter)

            drawContext.canvas.nativeCanvas.drawText(
                firstDateText,
                0f,
                height + 40f,
                textPaint,
            )
            val lastTextWidth = textPaint.measureText(lastDateText)
            drawContext.canvas.nativeCanvas.drawText(
                lastDateText,
                width - lastTextWidth,
                height + 40f,
                textPaint,
            )
        }
    }
}

private fun formatChartValue(value: Double, label: String): String {
    return when (label) {
        "sec" -> {
            val rounded = value.toInt().coerceAtLeast(0)
            val minutes = rounded / 60
            val seconds = rounded % 60
            "%d:%02d".format(minutes, seconds)
        }
        else -> formatWeightValue(value)
    }
}
