const fs=require('fs');let p='scripts/game.gd',s=fs.readFileSync(p,'utf8').replace('5.5.0','5.5').replace('var desired_speed = 4.0 if','var desired_speed = 2.4 if');fs.writeFileSync(p,s);
p='scripts/world.gd';s=fs.readFileSync(p,'utf8');s=s.replace('var columns = terrain_columns(z)\n\t\tfor ix','var columns = terrain_columns(z)\n\t\tvar next_columns = terrain_columns(z + STEP)\n\t\tfor ix');s=s.replace('var c = Vector3(x + width, ground(x + width, z + STEP), z + STEP)\n\t\t\tvar d = Vector3(x, ground(x, z + STEP), z + STEP)','var nx: float = next_columns[ix]\n\t\t\tvar nx1: float = next_columns[ix + 1]\n\t\t\tvar c = Vector3(nx1, ground(nx1, z + STEP), z + STEP)\n\t\t\tvar d = Vector3(nx, ground(nx, z + STEP), z + STEP)');
let a=s.indexOf('var column_cache:'),b=s.indexOf('func triangle(',a);s=s.slice(0,a)+`var column_cache: Dictionary = {}
func cached_columns(z: float) -> Array:
	if not column_cache.has(z):
		if column_cache.size() > 1200: column_cache.clear()
		column_cache[z] = terrain_columns(z)
	return column_cache[z]

func drive_height(x: float, z: float) -> float:
	var z0 = floor(z / STEP) * STEP
	var v = (z - z0) / STEP
	var row0 = cached_columns(z0)
	var row1 = cached_columns(z0 + STEP)
	var lo = 0
	var hi = row0.size() - 1
	while hi - lo > 1:
		var mid = int((lo + hi) / 2)
		if x < lerpf(row0[mid], row1[mid], v): hi = mid
		else: lo = mid
	var a: float = ground(row0[lo], z0)
	var b: float = ground(row0[hi], z0)
	var c: float = ground(row1[hi], z0 + STEP)
	var d: float = ground(row1[lo], z0 + STEP)
	var diagonal = lerpf(row0[lo], row1[hi], v)
	if x >= diagonal:
		var u = (x - diagonal) / maxf(0.00001, row0[hi] - row0[lo])
		return a + (b - a) * u + (c - a) * v
	var u = (x - lerpf(row0[lo], row1[lo], v)) / maxf(0.00001, row1[hi] - row1[lo])
	return a + (c - d) * u + (d - a) * v

`+s.slice(b);fs.writeFileSync(p,s);
p='scripts/interface.gd';s=fs.readFileSync(p,'utf8').replace('Перевал < / долина >','Свободная экспедиция');fs.writeFileSync(p,s);
