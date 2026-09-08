const fs=require('fs');let s=fs.readFileSync('scripts/game.gd','utf8');
s=s.replace('1.0 - exp(-delta * 1.5))\n\t\tcamera_idle', '1.0 - exp(-delta * (4.5 if abs(height_delta) > 1.2 else 1.5)))\n\t\tcamera_idle');
s=s.replace('camera.position = camera.position.lerp(target,', 'if started and camera_mode != 2:\n\t\ttarget = world.safe_camera(look, target)\n\tcamera.position = camera.position.lerp(target,');
s=s.replace('camera.look_at(look)','if started and camera_mode != 2 and world.camera_blocked(camera.position): camera.position = target\n\tcamera.look_at(look)');
fs.writeFileSync('scripts/game.gd',s);
