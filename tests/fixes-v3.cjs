const fs=require('fs');let s=fs.readFileSync('scripts/world.gd','utf8');
s=s.replace('road_y(z) + branch_amount(z) * 34.0','road_y(z) + pow(branch_amount(z), 2) * 34.0');
s=s.replace('var rd = abs(x - river_x(z))','base = lerpf(road_y(z) - 0.25, base, smoothstep(3.8, 8, d))\n\tvar rd = abs(x - river_x(z))');
fs.writeFileSync('scripts/world.gd',s);
s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('var low_range = false','var low_range = false\nvar bog_warning = 0.0');
s=s.replace('dynamics.step(self, throttle, steer, brake, delta)',`dynamics.step(self, throttle, steer, brake, delta)
	if abs(speed) < 0.4 and throttle > 0.5 and world.mud_at(van.position.x, van.position.z):
		bog_warning += delta
		if bog_warning > 5:
			toast("Увязли. L — пониженная, F — лебёдка. Грязевые шины помогут на подъёме.")
			bog_warning = 0
	else: bog_warning = 0`);
fs.writeFileSync('scripts/game.gd',s);
for(const file of ['game.gd','interface.gd','world.gd']){let text=fs.readFileSync('scripts/'+file,'utf8');text=text.replaceAll('₽','руб.').replaceAll('→','>').replaceAll('←','<');fs.writeFileSync('scripts/'+file,text);}
s=fs.readFileSync('tests/smoke.gd','utf8');
s=s.replace('scene.start_trip()','scene.levels[0] = 2\n\tscene.van.update_upgrades(scene.levels)\n\tscene.start_trip()');
s=s.replace('scene.money = 12000','scene.levels = [0, 0, 0, 0]\n\tscene.money = 12000');
fs.writeFileSync('tests/smoke.gd',s);
