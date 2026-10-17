.pragma library

// This is the same surface and camera as login.vert. Only a masked count is
// ever supplied by a password widget; this module never handles credentials.
function point(radius, meridian, phase, width, height) {
    var spin = 2.4
    var angle = meridian + spin * Math.exp(-radius / 22)
    var tail = 8 / 118
    var depression = (8 / (radius + 8) - tail) / (1 - tail)
    var x = Math.cos(angle) * radius
    var y = -34 * depression - 62
    var z = Math.sin(angle) * radius - 72
    var length = Math.sqrt(82 * 82 + 72 * 72)
    var fy = -82 / length, fz = -72 / length
    var depth = y * fy + z * fz
    var vertical = y * (-fz) + z * fy
    return Qt.point(width * 0.5 + x * 2.35 / depth * height * 0.5,
                    height * (0.5 - vertical * 2.35 / depth * 0.5))
}

function radius(step) { return 48 * Math.exp(-step * 0.15) }
