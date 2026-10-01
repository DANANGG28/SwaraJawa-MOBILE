package com.example.sjmobile.widget

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import com.example.sjmobile.MainActivity
import com.example.sjmobile.R
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.util.Calendar

/**
 * Menggambar kedua Home Screen Widget dari data yang dikirim Flutter lewat
 * plugin `home_widget` (SharedPreferences "HomeWidgetPreferences").
 *
 * Kunci data: streak, highest_streak, total_exp, nama, active_days
 * (CSV tanggal ISO yyyy-MM-dd).
 */
object WidgetRenderer {

    private const val KEY_STREAK = "streak"
    private const val KEY_HIGHEST = "highest_streak"
    private const val KEY_EXP = "total_exp"
    private const val KEY_NAMA = "nama"
    private const val KEY_ACTIVE_DAYS = "active_days"

    private val BULAN = arrayOf(
        "JANUARI", "FEBRUARI", "MARET", "APRIL", "MEI", "JUNI",
        "JULI", "AGUSTUS", "SEPTEMBER", "OKTOBER", "NOVEMBER", "DESEMBER",
    )

    private val CELL_IDS = intArrayOf(
        R.id.cal_cell_0, R.id.cal_cell_1, R.id.cal_cell_2, R.id.cal_cell_3,
        R.id.cal_cell_4, R.id.cal_cell_5, R.id.cal_cell_6, R.id.cal_cell_7,
        R.id.cal_cell_8, R.id.cal_cell_9, R.id.cal_cell_10, R.id.cal_cell_11,
        R.id.cal_cell_12, R.id.cal_cell_13, R.id.cal_cell_14, R.id.cal_cell_15,
        R.id.cal_cell_16, R.id.cal_cell_17, R.id.cal_cell_18, R.id.cal_cell_19,
        R.id.cal_cell_20, R.id.cal_cell_21, R.id.cal_cell_22, R.id.cal_cell_23,
        R.id.cal_cell_24, R.id.cal_cell_25, R.id.cal_cell_26, R.id.cal_cell_27,
        R.id.cal_cell_28, R.id.cal_cell_29, R.id.cal_cell_30, R.id.cal_cell_31,
        R.id.cal_cell_32, R.id.cal_cell_33, R.id.cal_cell_34, R.id.cal_cell_35,
        R.id.cal_cell_36, R.id.cal_cell_37, R.id.cal_cell_38, R.id.cal_cell_39,
        R.id.cal_cell_40, R.id.cal_cell_41,
    )

    private val ROW_IDS = intArrayOf(
        R.id.cal_row_0, R.id.cal_row_1, R.id.cal_row_2,
        R.id.cal_row_3, R.id.cal_row_4, R.id.cal_row_5,
    )

    private const val WARNA_TANGGAL = 0xFFEDE9FF.toInt()
    private const val WARNA_HARI_INI = 0xFF4338CA.toInt()
    private const val WARNA_AKTIF = 0xFFFFFFFF.toInt()

    fun renderCalendar(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        data: SharedPreferences,
    ) {
        val streak = data.getInt(KEY_STREAK, 0)
        val nama = data.getString(KEY_NAMA, null)

        val sekarang = Calendar.getInstance()
        val tahun = sekarang.get(Calendar.YEAR)
        val bulan = sekarang.get(Calendar.MONTH)
        val hariIni = sekarang.get(Calendar.DAY_OF_MONTH)

        val aktif = HashSet<String>()
        data.getString(KEY_ACTIVE_DAYS, "")
            ?.split(',')
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.let { aktif.addAll(it) }
        // Estimasi: streak hari terakhir s/d hari ini.
        for (i in 0 until streak) {
            aktif.add(iso(sekarang.timeInMillis - i * 86_400_000L))
        }

        val hariDalamBulan = sekarang.getActualMaximum(Calendar.DAY_OF_MONTH)
        val selHariPertama = ((sekarang.clone() as Calendar).apply {
            set(Calendar.DAY_OF_MONTH, 1)
        }.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Senin = 0
        val jumlahBaris = ((selHariPertama + hariDalamBulan) + 6) / 7

        val views = RemoteViews(context.packageName, R.layout.streak_calendar_widget)
        views.setTextViewText(R.id.widget_greeting, sapaan(sekarang, nama))
        views.setTextViewText(
            R.id.widget_month,
            "${BULAN[bulan]} $tahun",
        )
        views.setTextViewText(R.id.widget_streak_num, streak.toString())
        views.setImageViewResource(
            R.id.widget_mascot,
            if (streak > 0) R.drawable.mascot_happy else R.drawable.mascot_sleepy,
        )

        for (baris in 0 until 6) {
            views.setViewVisibility(
                ROW_IDS[baris],
                if (baris < jumlahBaris) android.view.View.VISIBLE else android.view.View.GONE,
            )
        }

        for (i in CELL_IDS.indices) {
            val id = CELL_IDS[i]
            val hari = i - selHariPertama + 1
            if (hari < 1 || hari > hariDalamBulan) {
                views.setTextViewText(id, "")
                views.setInt(id, "setBackgroundResource", 0)
                continue
            }

            val kunci = isoHari(tahun, bulan, hari)
            val isHariIni = hari == hariIni
            val isAktif = aktif.contains(kunci)

            views.setTextViewText(id, hari.toString())
            when {
                isHariIni -> {
                    views.setInt(id, "setBackgroundResource", R.drawable.cal_day_today)
                    views.setTextColor(id, WARNA_HARI_INI)
                }
                isAktif -> {
                    views.setInt(id, "setBackgroundResource", R.drawable.cal_day_active)
                    views.setTextColor(id, WARNA_AKTIF)
                }
                else -> {
                    views.setInt(id, "setBackgroundResource", R.drawable.cal_day_idle)
                    views.setTextColor(id, WARNA_TANGGAL)
                }
            }
        }

        val buka = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root, buka)

        for (id in ids) {
            manager.updateAppWidget(id, views)
        }
    }

    fun renderMini(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
        data: SharedPreferences,
    ) {
        val streak = data.getInt(KEY_STREAK, 0)

        val views = RemoteViews(context.packageName, R.layout.streak_mini_widget)
        views.setTextViewText(R.id.widget_streak_num_mini, streak.toString())
        views.setTextViewText(R.id.widget_tagline_mini, tagline(streak))
        views.setImageViewResource(
            R.id.widget_mascot_mini,
            if (streak > 0) R.drawable.mascot_happy else R.drawable.mascot_sleepy,
        )

        val buka = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        views.setOnClickPendingIntent(R.id.widget_root_mini, buka)

        for (id in ids) {
            manager.updateAppWidget(id, views)
        }
    }

    private fun sapaan(sekarang: Calendar, nama: String?): String {
        val jam = sekarang.get(Calendar.HOUR_OF_DAY)
        val sapa = when {
            jam < 4 -> "Sugeng dalu"
            jam < 11 -> "Sugeng enjing"
            jam < 15 -> "Sugeng siang"
            jam < 18 -> "Sugeng sonten"
            else -> "Sugeng dalu"
        }
        return if (nama.isNullOrBlank()) sapa else "$sapa, $nama"
    }

    private fun tagline(streak: Int): String = when {
        streak <= 0 -> "Ayo miwiti dina iki!"
        streak == 1 -> "Wiwitan sing apik!"
        streak < 7 -> "Terus semangat!"
        streak < 30 -> "Keren tenan!"
        else -> "Luar biasa!"
    }

    private fun isoHari(tahun: Int, bulan: Int, hari: Int): String {
        val c = Calendar.getInstance().apply {
            set(tahun, bulan, hari, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        return iso(c.timeInMillis)
    }

    private fun iso(millis: Long): String {
        val c = Calendar.getInstance().apply {
            timeInMillis = millis
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val y = c.get(Calendar.YEAR)
        val m = c.get(Calendar.MONTH) + 1
        val d = c.get(Calendar.DAY_OF_MONTH)
        return "%04d-%02d-%02d".format(y, m, d)
    }
}
