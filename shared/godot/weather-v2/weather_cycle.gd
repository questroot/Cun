extends RefCounted
## Visual state, not hydrological mass/energy simulation. Seconds are accelerated review time.
signal event_selected(kind:String)
signal emission_ended
const EVENT_END:={"rain":42.0,"snow":35.0,"fog":30.0}
var elapsed:=0.0
var rain:=0.0
var wetness:=0.0
var pooling:=0.0
var snowfall:=0.0
var snow_cover:=0.0
var fog:=0.0
var stage:="干地"
var scenario:="rain"
var strength:=1.0

func apply_gallery_intent(intent:Dictionary)->void:
	var kind:String=str(intent.get("scenario","rain"))
	var level:float=float(intent.get("strength",1.0))
	strength=clampf(level,0.0,1.0) if is_finite(level) else 1.0
	reset(kind if kind in ["rain","snow","fog"] else "rain")

func reset(kind:String="rain")->void:
	elapsed=0.0
	rain=0.0
	wetness=0.0
	pooling=0.0
	snowfall=0.0
	snow_cover=0.0
	fog=0.0
	scenario=kind
	event_selected.emit(kind)
# Manual weather selection starts a new event, not a new landscape.
func select_event(kind:String)->void:
	if kind not in ["rain","snow","fog"]:return
	scenario=kind
	elapsed=0.0
	event_selected.emit(kind)

# Stop emission without discarding already wet ground, snow, or fog.
func stop_event()->void:
	var end:float=EVENT_END.get(scenario,42.0)
	if elapsed<end:
		elapsed=end
		emission_ended.emit()

func member_summary()->String:
	var parts:=PackedStringArray()
	if scenario=="rain" or rain>0:parts.append("雨量 %d%%"%ceili(rain*100))
	if scenario=="snow" or snowfall>0:parts.append("降雪 %d%%"%ceili(snowfall*100))
	if snow_cover>0:parts.append("积雪 %d%%"%ceili(snow_cover*100))
	if scenario=="fog" or fog>0:parts.append("雾量 %d%%"%ceili(fog*100))
	if wetness>0:parts.append("湿润 %d%%"%ceili(wetness*100))
	if pooling>0:parts.append("积水 %d%%"%ceili(pooling*100))
	return "  ".join(parts)

func advance(delta:float)->void:
	var dt:=maxf(delta,0.0)
	var end:float=EVENT_END.get(scenario,42.0)
	var was_emitting:=elapsed<end
	elapsed+=dt
	if was_emitting and elapsed>=end:emission_ended.emit()
	var target:=0.0
	if scenario=="rain":
		if elapsed<5:stage="等待降雨" if wetness>0 or snow_cover>0 or pooling>0 or fog>0 or rain>0 else "干地"
		elif elapsed<17:stage="小雨打湿";target=0.28
		elif elapsed<42:stage="持续降雨积水";target=0.9
		else:stage="停雨后缓慢恢复"
		var requested:=target*strength
		rain=move_toward(rain,requested,dt*(0.16 if requested>rain else 0.28))

	elif scenario=="snow":
		if elapsed<5:stage="等待降雪"
		elif elapsed<35:stage="飘雪与表面留存";target=0.8
		else:stage="停雪后渐融"
		snowfall=move_toward(snowfall,target*strength,dt*0.12)

	elif scenario=="fog":
		if elapsed<5:stage="等待起雾"
		elif elapsed<30:stage="雾渐入";target=0.85
		else:stage="雾渐散"
		fog=move_toward(fog,target*strength,dt*0.045)
	if scenario!="rain":rain=move_toward(rain,0.0,dt*0.28)
	if scenario!="snow":snowfall=move_toward(snowfall,0.0,dt*0.12)
	if scenario!="fog":fog=move_toward(fog,0.0,dt*0.045)
	var previous_cover:=snow_cover
	# The supported 小雪 preset peaks at 0.24: under the old constant thaw
	# its net deposition was negative even on bare ground. Ease thaw while
	# snow is actually falling; keep the original dry-weather melt rate.
	var thaw_rate:=lerpf(0.018,0.009,smoothstep(0.0,0.24,snowfall))
	snow_cover=clampf(snow_cover+dt*(snowfall*0.055-(1-snowfall)*thaw_rate),0,1)
	var melted:=maxf(previous_cover-snow_cover,0.0)
	# Residual snow, not the selected menu item, shelters the damp ground.
	# Blend across the final thin layer instead of switching rate at zero cover.
	var drying:=lerpf(0.022,0.009*(1.0-snow_cover),smoothstep(0.0,0.12,snow_cover))
	# Pooled water keeps the underlying ground damp during drainage. Release
	# to the ordinary evaporation rate smoothly as the last shallow water goes.
	drying*=lerpf(1.0,0.35,smoothstep(0.0,0.20,pooling))
	# A fresh film from thaw cannot evaporate like an already soaked surface.
	# Ease evaporation at low moisture, independently of the selected weather.
	if melted>0.0:drying*=smoothstep(0.0,0.20,wetness)
	wetness=clampf(wetness+melted*0.65+dt*(rain*0.13-(1-rain)*drying),0,1)
	pooling=clampf(pooling+dt*(maxf(rain-0.25,0)*wetness*0.075-(1-rain)*0.018),0,1)
	wetness=maxf(wetness,pooling)
