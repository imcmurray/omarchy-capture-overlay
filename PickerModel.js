.pragma library

var SIZES = [
  { w: 1920, h: 1080, label: "1080p" },
  { w: 1280, h: 720, label: "720p" },
  { w: 1600, h: 900, label: "900p" },
  { w: 854, h: 480, label: "480p" },
  { w: 2560, h: 1440, label: "1440p" },
  { w: 2560, h: 1080, label: "1080 ultra" }
]

var SNAP = 32
var MIN = 32
var HANDLE = 12
var GHOST_HIT = 10

function sizesFor(sw, sh) {
  var out = []
  for (var i = 0; i < SIZES.length; i++) {
    if (SIZES[i].w <= sw && SIZES[i].h <= sh)
      out.push(SIZES[i])
  }
  return out
}

function clampRect(r, sx, sy, sw, sh) {
  var x = Number(r.x)
  var y = Number(r.y)
  var w = Number(r.w)
  var h = Number(r.h)
  if (w < MIN) w = MIN
  if (h < MIN) h = MIN
  if (x < sx) {
    w -= sx - x
    x = sx
  }
  if (y < sy) {
    h -= sy - y
    y = sy
  }
  if (x + w > sx + sw) w = sx + sw - x
  if (y + h > sy + sh) h = sy + sh - y
  if (w < MIN) w = MIN
  if (h < MIN) h = MIN
  if (x + w > sx + sw) x = sx + sw - w
  if (y + h > sy + sh) y = sy + sh - h
  if (x < sx) x = sx
  if (y < sy) y = sy
  return {
    x: Math.round(x),
    y: Math.round(y),
    w: Math.round(Math.max(MIN, w)),
    h: Math.round(Math.max(MIN, h))
  }
}

function rectFromPoints(x0, y0, x1, y1) {
  return {
    x: Math.min(x0, x1),
    y: Math.min(y0, y1),
    w: Math.abs(x1 - x0),
    h: Math.abs(y1 - y0),
    dirX: x1 >= x0 ? 1 : -1,
    dirY: y1 >= y0 ? 1 : -1,
    anchorX: x0,
    anchorY: y0
  }
}

function ghosts(anchorX, anchorY, dirX, dirY, sx, sy, sw, sh) {
  var sizes = sizesFor(sw, sh)
  var out = []
  var dx = dirX < 0 ? -1 : 1
  var dy = dirY < 0 ? -1 : 1
  for (var i = 0; i < sizes.length; i++) {
    var s = sizes[i]
    var x = dx < 0 ? anchorX - s.w : anchorX
    var y = dy < 0 ? anchorY - s.h : anchorY
    if (x < sx || y < sy || x + s.w > sx + sw || y + s.h > sy + sh)
      continue
    out.push({ x: x, y: y, w: s.w, h: s.h, label: s.label })
  }
  out.sort(function (a, b) { return b.w * b.h - a.w * a.h })
  return out
}

function sameRect(a, b) {
  if (!a || !b) return false
  return a.x === b.x && a.y === b.y && a.w === b.w && a.h === b.h
}

function visibleGhosts(list, current) {
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (!sameRect(list[i], current))
      out.push(list[i])
  }
  return out
}

function snapToGhosts(r, list, threshold) {
  var t = threshold || SNAP
  var best = null
  var bestScore = t * 2 + 1
  for (var i = 0; i < list.length; i++) {
    var g = list[i]
    var dw = Math.abs(r.w - g.w)
    var dh = Math.abs(r.h - g.h)
    if (dw <= t && dh <= t) {
      var score = dw + dh
      if (score < bestScore) {
        bestScore = score
        best = g
      }
    }
  }
  if (!best)
    return { x: r.x, y: r.y, w: r.w, h: r.h, snapped: "" }
  return { x: best.x, y: best.y, w: best.w, h: best.h, snapped: best.label }
}

function matchingLabel(r) {
  for (var i = 0; i < SIZES.length; i++) {
    if (SIZES[i].w === r.w && SIZES[i].h === r.h)
      return SIZES[i].label
  }
  return ""
}

function inside(px, py, r) {
  return !!r && px >= r.x && px <= r.x + r.w && py >= r.y && py <= r.y + r.h
}

function nearBorder(px, py, r, slop) {
  if (!r) return false
  var s = slop || GHOST_HIT
  var outer = px >= r.x - s && px <= r.x + r.w + s && py >= r.y - s && py <= r.y + r.h + s
  var inner = px >= r.x + s && px <= r.x + r.w - s && py >= r.y + s && py <= r.y + r.h - s
  return outer && !inner
}

function hitHandle(px, py, r, slop) {
  if (!r) return ""
  var s = slop || HANDLE
  var x = r.x
  var y = r.y
  var w = r.w
  var h = r.h
  var left = px >= x - s && px <= x + s
  var right = px >= x + w - s && px <= x + w + s
  var top = py >= y - s && py <= y + s
  var bottom = py >= y + h - s && py <= y + h + s
  var inX = px >= x - s && px <= x + w + s
  var inY = py >= y - s && py <= y + h + s
  if (top && left) return "nw"
  if (top && right) return "ne"
  if (bottom && left) return "sw"
  if (bottom && right) return "se"
  if (top && inX) return "n"
  if (bottom && inX) return "s"
  if (left && inY) return "w"
  if (right && inY) return "e"
  return ""
}

function distToBorder(px, py, r) {
  var left = r.x
  var right = r.x + r.w
  var top = r.y
  var bottom = r.y + r.h
  var dl = Math.abs(px - left)
  var dr = Math.abs(px - right)
  var dt = Math.abs(py - top)
  var db = Math.abs(py - bottom)
  var inX = px >= left && px <= right
  var inY = py >= top && py <= bottom
  if (inX && inY)
    return Math.min(dl, dr, dt, db)
  if (inX)
    return py < top ? dt : db
  if (inY)
    return px < left ? dl : dr
  var dx = px < left ? left - px : px - right
  var dy = py < top ? top - py : py - bottom
  return Math.sqrt(dx * dx + dy * dy)
}

function hitGhost(px, py, list) {
  var best = null
  var bestD = GHOST_HIT + 1
  for (var i = 0; i < list.length; i++) {
    var g = list[i]
    if (!nearBorder(px, py, g, GHOST_HIT))
      continue
    var d = distToBorder(px, py, g)
    var smaller = best && g.w * g.h < best.w * best.h
    if (d < bestD || (d === bestD && smaller)) {
      bestD = d
      best = g
    }
  }
  return best
}

function resize(start, handle, px, py) {
  var x = start.x
  var y = start.y
  var x2 = start.x + start.w
  var y2 = start.y + start.h
  if (handle.indexOf("w") !== -1) x = px
  if (handle.indexOf("e") !== -1) x2 = px
  if (handle.indexOf("n") !== -1) y = py
  if (handle.indexOf("s") !== -1) y2 = py
  return {
    x: Math.min(x, x2),
    y: Math.min(y, y2),
    w: Math.abs(x2 - x),
    h: Math.abs(y2 - y)
  }
}

function move(start, dx, dy) {
  return { x: start.x + dx, y: start.y + dy, w: start.w, h: start.h }
}

function cursorForHandle(handle) {
  if (handle === "n" || handle === "s") return "ns"
  if (handle === "e" || handle === "w") return "ew"
  if (handle === "ne" || handle === "sw") return "nesw"
  if (handle === "nw" || handle === "se") return "nwse"
  return ""
}
