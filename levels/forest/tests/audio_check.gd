extends SceneTree
## 檢查森林的聲音：合成要多久、每個聲音多長、有沒有聲音、會不會爆音；順便存成 .wav 方便試聽。
## Godot --headless --path . --script res://levels/forest/tests/audio_check.gd -- <輸出資料夾>
const ForestSfx := preload("res://levels/forest/forest_sfx.gd")

func _initialize() -> void:
	var out := "user://forest_audio"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var t0 := Time.get_ticks_msec()
	var all := ForestSfx.make_all()
	print("合成 %d 個聲音：%d 毫秒" % [all.size(), Time.get_ticks_msec() - t0])
	var bad := 0
	for k in all:
		var w: AudioStreamWAV = all[k]
		var d := w.data
		var n := d.size() / 2
		var peak := 0
		var sum := 0.0
		for i in n:
			var v := absi(d.decode_s16(i * 2))
			peak = maxi(peak, v)
			sum += float(v) * float(v)
		var rms := sqrt(sum / maxf(n, 1)) / 30000.0
		var ok := peak > 3000 and peak <= 30000 and rms > 0.01
		if not ok:
			bad += 1
		print("  %-9s %5.2f 秒  峰值 %.2f  RMS %.3f %s%s" % [k, w.get_length(), peak / 30000.0, rms,
			"循環" if w.loop_mode != AudioStreamWAV.LOOP_DISABLED else "", "" if ok else "  ← 有問題"])
		w.save_to_wav(out.path_join(k + ".wav"))
	var run: AudioStreamWAV = all["bgm_run"]
	var plan: AudioStreamWAV = all["bgm_plan"]
	print("兩首配樂一樣長（切換不斷拍）：", run.data.size() == plan.data.size())
	print("AUDIO: ALL PASS" if bad == 0 and run.data.size() == plan.data.size() else "AUDIO: FAILED (%d)" % bad)
	print("wav -> ", ProjectSettings.globalize_path(out))
	quit(1 if bad > 0 else 0)
