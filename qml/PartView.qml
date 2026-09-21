// Küçük bileşenler (bakış butonları, açıklama) "view" kimliğine güvenle erişebilsin.
pragma ComponentBehavior: Bound

import QtQuick

// SİMÜLASYON: parçanın üç boyutlu çizimi (müşterinin ekranındaki SİMÜLASYON sekmesi).
//
// Şekli PartShape hesaplar (C++): borunun eksen çizgisi, kısa parçalara bölünmüş olarak.
// Burada yalnızca çizilir, bir ressamın yapacağı gibi:
//   1. Her nokta ekrana izdüşürülür: parçanın etrafında dönen bir gözden bakılır
//      (azimuth: yatay açı, elevation: yukarıdan bakış açısı). Uzaklık küçültme yapmaz
//      (paralel izdüşüm, teknik resimdeki gibi).
//   2. Boru şeritlere ayrılır ve şeritler uzaktan yakına boyanır: borunun önden geçen
//      yeri arkadakinin üstüne düşer (ressam algoritması). Boru ekranda kendi üstünden
//      geçmiyorsa tek parça, dikişsiz çizilir.
//   3. Şerit, borunun iki kenarı arasındaki bir çokgendir (dolgu); kenarları koyu
//      çizgiler, üstünde ışığı gösteren açık bir parıltı var. Boru göze doğru dönünce
//      kesiti elips görünür: uçlar ve göze dönük yerler böyle tamamlanır.
//      Uzaktaki yerler biraz soluk boyanır: derinlik böyle hissedilir.
// Borunun kalınlığı gerçek çapıdır (ölçekli). Görünüm parçaya her an sığdırılır.
// ÜST, YAN ve 3B hazır bakış açılarıdır; parmakla sürükleyerek de döndürülür.
Rectangle {
    id: view

    required property BendProgram program

    // Üretim renkleri: progressStep'ten önceki adımlar bitti (koyu), kendisi işleniyor
    // (turuncu), sonrakiler sırada (açık). -1: hiçbiri başlamadı; adım sayısı: hepsi bitti.
    property bool production: false
    property int progressStep: -1

    // Tasarımda seçili adım: mavi çizilir (-1: seçim yok).
    property int highlightStep: -1

    // Bakış açısı (derece). Hazır bakışlar: ÜST (tepeden), YAN (yandan), 3B (çapraz).
    property real azimuth: 35
    property real elevation: 30
    property string preset: "3d" // seçili hazır bakış; sürükleyince boşalır

    // Durum ve testler için
    readonly property var pieces: shape.pieces
    readonly property var labels: shape.labels
    readonly property int pieceCount: view.pieces.length
    property int paintCount: 0
    property int runCount: 0
    property real paintMs: 0 // son çizimin süresi (performans denetimi için)
    // Son çizimin izdüşümü: ekran = (ox, oy) + k × (nokta − merkez)·(r, −u)
    property var projection: ({})
    // Adım numarası rozetlerinin yerleri (çizimle birlikte hesaplanır)
    property var badgeSpots: []

    // Çizim alanının kenar payları (px): sağda bakış butonları, altta açıklama satırı.
    readonly property int rightMargin: 68
    readonly property int bottomMargin: 26
    readonly property int edgeMargin: 10

    // Zemin rengi ("#rrggbb"): uzaktaki borular bu renge doğru solar.
    readonly property string background: "#ffffff"

    // Renkler: dolgu, kenar, parıltı ve adım numarası rozeti.
    readonly property var tubeColors: ({
        "normal": { fill: "#7d8a99", edge: "#3f4a56", shine: "#d3dae2",
                    badge: "#ffffff", badgeEdge: "#3f4a56", badgeText: "#1c2229" },
        "current": { fill: "#e39b2d", edge: "#8a5300", shine: "#f8dcaa",
                     badge: "#c77800", badgeEdge: "#8a5300", badgeText: "#ffffff" },
        "remaining": { fill: "#dfe3e8", edge: "#a7afb9", shine: "#f5f7f9",
                       badge: "#ffffff", badgeEdge: "#a7afb9", badgeText: "#8b949e" },
        "selected": { fill: "#4f86c6", edge: "#1f4e8c", shine: "#c9ddf4",
                      badge: "#1f4e8c", badgeEdge: "#1f4e8c", badgeText: "#ffffff" }
    })

    // Bir adım hangi renkle çizilir?
    function stateOf(step: int): string {
        if (view.production) {
            if (step === view.progressStep)
                return "current"
            return step < view.progressStep ? "normal" : "remaining"
        }
        return step === view.highlightStep ? "selected" : "normal"
    }

    // Hazır bakışa dön (açılar kısa yoldan, yumuşakça değişir).
    function showPreset(name: string) {
        const targetAzimuth = name === "3d" ? 35 : 0
        const targetElevation = name === "top" ? 90 : name === "side" ? 0 : 30
        // Açı 360'ın katı kadar farklı olabilir (sürüklenmişse): en kısa yoldan dön.
        let current = view.azimuth % 360
        if (current - targetAzimuth > 180)
            current -= 360
        else if (current - targetAzimuth < -180)
            current += 360
        presetAnimation.stop()
        view.azimuth = current
        azimuthAnimation.to = targetAzimuth
        elevationAnimation.to = targetElevation
        view.preset = name
        presetAnimation.start()
    }

    function repaint() {
        if (canvas.visible)
            canvas.requestPaint()
    }

    onPiecesChanged: view.repaint()
    onAzimuthChanged: view.repaint()
    onElevationChanged: view.repaint()
    onProductionChanged: view.repaint()
    onProgressStepChanged: view.repaint()
    onHighlightStepChanged: view.repaint()

    Connections {
        target: view.program

        // Boru çapı değişince çizgi kalınlığı değişir.
        function onTubeChanged() {
            view.repaint()
        }
    }

    radius: Theme.radius
    color: view.background
    border.color: Theme.panelBorder

    PartShape {
        id: shape

        program: view.program
    }

    ParallelAnimation {
        id: presetAnimation

        NumberAnimation {
            id: azimuthAnimation

            target: view
            property: "azimuth"
            duration: 350
            easing.type: Easing.InOutQuad
        }

        NumberAnimation {
            id: elevationAnimation

            target: view
            property: "elevation"
            duration: 350
            easing.type: Easing.InOutQuad
        }
    }

    // ------------------------------------------------------------------
    // Hesap: bakış yönleri ve izdüşüm
    // ------------------------------------------------------------------

    // Ekranın sağı (r), yukarısı (u) ve göze doğru yön (d), parçanın çerçevesinde.
    // Parçanın ana düzlemi ilk dirseğin düzlemidir: X ilk düz parçanın yönü, N o
    // düzlemin dik yönü, Y = N × X. ÜST bakış N'den, YAN bakış -Y'den bakar.
    function viewBasis() {
        const normal = shape.planeNormal
        const n = [normal.x, normal.y, normal.z]
        const x = [1, 0, 0]
        const y = [n[1] * x[2] - n[2] * x[1], n[2] * x[0] - n[0] * x[2], n[0] * x[1] - n[1] * x[0]]
        const a = view.azimuth * Math.PI / 180
        const e = view.elevation * Math.PI / 180
        const r = [0, 1, 2].map(i => Math.cos(a) * x[i] + Math.sin(a) * y[i])
        const d = [0, 1, 2].map(i => Math.cos(e) * (Math.sin(a) * x[i] - Math.cos(a) * y[i])
                                     + Math.sin(e) * n[i])
        const u = [d[1] * r[2] - d[2] * r[1], d[2] * r[0] - d[0] * r[2], d[0] * r[1] - d[1] * r[0]]
        return { r: r, u: u, d: d }
    }

    // Parçadaki bir noktanın bakış koordinatları (mm): x sağa, y yukarı, depth göze doğru.
    function toView(px: real, py: real, pz: real, basis, center: vector3d) {
        const dx = px - center.x, dy = py - center.y, dz = pz - center.z
        return {
            x: dx * basis.r[0] + dy * basis.r[1] + dz * basis.r[2],
            y: dx * basis.u[0] + dy * basis.u[1] + dz * basis.u[2],
            depth: dx * basis.d[0] + dy * basis.d[1] + dz * basis.d[2]
        }
    }

    // İki rengi karıştır (t = 0: a, t = 1: b). Renkler "#rrggbb" biçiminde.
    function mix(a: string, b: string, t: real): string {
        const channel = (color, i) => parseInt(color.substr(1 + 2 * i, 2), 16)
        const value = i => Math.round(channel(a, i) + (channel(b, i) - channel(a, i)) * t)
        return "rgb(" + value(0) + "," + value(1) + "," + value(2) + ")"
    }

    // ------------------------------------------------------------------
    // Çizim
    // ------------------------------------------------------------------

    function paintScene(ctx) {
        const startTime = Date.now()
        view.drawScene(ctx)
        view.paintMs = Date.now() - startTime
        view.paintCount += 1
    }

    function drawScene(ctx) {
        ctx.reset()

        const list = view.pieces
        const n = list.length
        const width = canvas.width, height = canvas.height
        if (n === 0 || width <= 0 || height <= 0) {
            view.runCount = 0
            view.projection = ({})
            view.badgeSpots = []
            return
        }

        // 1) Eksen çizgisinin noktaları (parçalar uç uca eklidir) bakış koordinatlarında
        const basis = view.viewBasis()
        const center = shape.center
        const points = [view.toView(list[0].x1, list[0].y1, list[0].z1, basis, center)]
        for (let i = 0; i < n; ++i)
            points.push(view.toView(list[i].x2, list[i].y2, list[i].z2, basis, center))

        // 2) Sığdırma: parçanın ekrandaki kutusu, boru kalınlığı ve rozetler için pay
        let minX = Infinity, maxX = -Infinity, minY = Infinity, maxY = -Infinity
        let near = -Infinity, far = Infinity
        for (const p of points) {
            minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x)
            minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y)
            near = Math.max(near, p.depth); far = Math.min(far, p.depth)
        }
        const diameter = Math.max(0, view.program.tubeDiameter)
        const left = view.edgeMargin, right = width - view.rightMargin
        const top = view.edgeMargin, bottom = height - view.bottomMargin
        const badgeRoom = 14
        const spanX = Math.max(1, maxX - minX + diameter), spanY = Math.max(1, maxY - minY + diameter)
        const k = Math.max(0.001, Math.min((right - left - 2 * badgeRoom) / spanX,
                                           (bottom - top - 2 * badgeRoom) / spanY))
        const ox = (left + right) / 2 - k * (minX + maxX) / 2
        const oy = (top + bottom) / 2 + k * (minY + maxY) / 2
        for (const p of points) {
            p.px = ox + k * p.x
            p.py = oy - k * p.y
        }
        const tube = Math.max(3, diameter * k)
        view.projection = {
            rx: basis.r[0], ry: basis.r[1], rz: basis.r[2],
            ux: basis.u[0], uy: basis.u[1], uz: basis.u[2],
            cx: center.x, cy: center.y, cz: center.z,
            k: k, ox: ox, oy: oy, tube: tube
        }

        // Her noktada borunun ekrandaki yönü (tx, ty) ve dik yönü (nx, ny): borunun iki
        // kenarı dik yönde, yarım kalınlık uzaktadır. steep: boru göze ne kadar dönük
        // (0: ekrana paralel, 1: tam göze doğru; o zaman kesiti bir daire gibi görünür).
        // Parıltı: ışık sol üstten gelir; parıltı ışığa bakan kenara kayar.
        const lightX = -0.55, lightY = -0.83
        for (let i = 0; i <= n; ++i) {
            const a = points[Math.max(0, i - 1)], b = points[Math.min(n, i + 1)]
            const dx = b.px - a.px, dy = b.py - a.py
            const length = Math.hypot(dx, dy)
            const tx = length > 1e-6 ? dx / length : 1
            const ty = length > 1e-6 ? dy / length : 0
            const along = Math.hypot(b.x - a.x, b.y - a.y, b.depth - a.depth)
            const p = points[i]
            p.tx = tx
            p.ty = ty
            p.nx = -ty
            p.ny = tx
            p.steep = along > 1e-9 ? Math.abs(b.depth - a.depth) / along : 0
            const facing = p.nx * lightX + p.ny * lightY
            p.shineX = p.px + p.nx * facing * 0.2 * tube
            p.shineY = p.py + p.ny * facing * 0.2 * tube
        }

        // 3) Şeritler: boru uzun şeritler halinde, dikişsiz çizilir. Yalnızca borunun
        // ekranda kendi başka bir yeriyle üst üste bindiği yerlerde şeritler kısalır:
        // derinliği borunun yarı çapından az değişen parçalar. Böylece önden geçen boru
        // arkadakinin üstüne düşer (ressam algoritması).
        const depthRange = near - far
        const overlapping = view.findOverlaps(points, list, tube, diameter)
        const maxExtent = Math.max(diameter / 2, depthRange / 40, 1e-6)
        const runs = []
        let run = {
            first: 0, key: view.stateOf(list[0].step), limited: overlapping[0],
            low: Math.min(points[0].depth, points[1].depth), high: Math.max(points[0].depth, points[1].depth)
        }
        for (let i = 1; i < n; ++i) {
            const key = view.stateOf(list[i].step)
            const depth = points[i + 1].depth
            const low = Math.min(run.low, depth), high = Math.max(run.high, depth)
            const limited = run.limited || overlapping[i]
            if (key !== run.key || (limited && high - low > maxExtent)) {
                run.last = i
                runs.push(run)
                run = {
                    first: i, key: key, limited: overlapping[i],
                    low: Math.min(points[i].depth, depth), high: Math.max(points[i].depth, depth)
                }
            } else {
                run.low = low
                run.high = high
                run.limited = limited
            }
        }
        run.last = n
        runs.push(run)
        for (const r of runs) {
            let sum = 0
            for (let v = r.first; v <= r.last; ++v)
                sum += points[v].depth
            r.depth = sum / (r.last - r.first + 1)
        }
        runs.sort((a, b) => a.depth - b.depth || a.first - b.first) // uzaktan yakına
        view.runCount = runs.length

        // Uzaklık solukluğu: en yakın nokta 0, en uzak 1
        const fogOf = depth => depthRange > 1e-6 ? (near - depth) / depthRange : 0

        // Boru göze doğru döndüğünde kesiti elips (tam dönükse daire) görünür ve gövdenin
        // dışına taşar (ör. yandan bakınca dirseğin ucu yuvarlak görünür). Bu kesitler
        // bütün şeritlerin altına konur: önce hepsi kenar renginde biraz geniş, sonra dolgu
        // renginde biraz dar (böylece yalnızca dış çevreleri kenar olur); gövdeler üstüne gelir.
        const edge = view.edgeWidth(tube)
        const caps = []
        for (let v = 0; v <= n; ++v) {
            if (v === 0 || v === n || points[v].steep >= 0.5)
                caps.push(v)
        }
        caps.sort((a, b) => points[a].depth - points[b].depth)
        for (const pass of ["edge", "fill"]) {
            for (const v of caps) {
                const p = points[v]
                const colors = view.tubeColors[view.stateOf(list[Math.min(v, n - 1)].step)]
                view.crossSection(ctx, p, tube / 2 + (pass === "edge" ? edge / 2 : -edge / 2), 0, 2 * Math.PI)
                ctx.fillStyle = pass === "edge" ? view.mix(colors.edge, view.background, 0.2 * fogOf(p.depth))
                                                : view.mix(colors.fill, view.background, 0.35 * fogOf(p.depth))
                ctx.fill()
            }
        }

        for (const r of runs)
            view.paintRun(ctx, points, r, tube, fogOf)

        // 4) Adım numaralarının yerleri: rozetleri QML öğeleri çizer (ekranın yazı tipiyle).
        // Rozetler üst üste binerse önemli olan kalır: işlenen ya da seçili adım önce, sonra
        // sırayla; yer bulamayan rozet gizlenir, uzun programlarda da parça görünür kalsın.
        const labels = view.labels
        const important = step => view.production ? step === view.progressStep : step === view.highlightStep
        const order = labels.map((label, i) => i)
        order.sort((i, j) => (important(labels[j].step) ? 1 : 0) - (important(labels[i].step) ? 1 : 0) || i - j)
        const spots = new Array(labels.length).fill(null)
        const placed = []
        for (const i of order) {
            const label = labels[i]
            const p = view.toView(label.x, label.y, label.z, basis, center)
            const x = canvas.x + ox + k * p.x, y = canvas.y + oy - k * p.y // tuval çerçevenin 1 px içinde
            const digits = String(label.step + 1).length
            const width = Math.max(22, 7 * digits + (label.command === BendProgram.Rotate ? 12 : 0) + 12)
            if (placed.some(r => Math.abs(r.x - x) < (r.width + width) / 2 + 2 && Math.abs(r.y - y) < 24))
                continue
            placed.push({ x: x, y: y, width: width })
            spots[i] = { x: x, y: y }
        }
        view.badgeSpots = spots
    }

    // Borunun ekranda kendi başka bir yeriyle üst üste bindiği parçalar (true/false).
    // Boru boyunca komşu parçalar (aralarında iki çaptan az boru olan) sayılmaz: onlar
    // zaten bitişik çizilir.
    function findOverlaps(points, list, tube: real, diameter: real) {
        const n = list.length
        const result = new Array(n).fill(false)
        const along = [0] // borunun başından uzaklık (mm)
        for (let i = 0; i < n; ++i) {
            const p = list[i]
            along.push(along[i] + Math.hypot(p.x2 - p.x1, p.y2 - p.y1, p.z2 - p.z1))
        }
        const reach = tube + 2
        for (let i = 0; i < n; ++i) {
            const a = points[i], b = points[i + 1]
            const minX = Math.min(a.px, b.px) - reach, maxX = Math.max(a.px, b.px) + reach
            const minY = Math.min(a.py, b.py) - reach, maxY = Math.max(a.py, b.py) + reach
            for (let j = i + 1; j < n; ++j) {
                if (along[j] - along[i + 1] < 2 * diameter)
                    continue
                const c = points[j], d = points[j + 1]
                if (Math.max(c.px, d.px) < minX || Math.min(c.px, d.px) > maxX
                    || Math.max(c.py, d.py) < minY || Math.min(c.py, d.py) > maxY)
                    continue
                if (view.segmentDistance(a, b, c, d) < reach) {
                    result[i] = true
                    result[j] = true
                }
            }
        }
        return result
    }

    // Ekrandaki iki doğru parçası arasındaki en kısa uzaklık (px); kesişiyorlarsa 0.
    function segmentDistance(a, b, c, d): real {
        const side = (p, q, r) => (q.px - p.px) * (r.py - p.py) - (q.py - p.py) * (r.px - p.px)
        const d1 = side(a, b, c), d2 = side(a, b, d), d3 = side(c, d, a), d4 = side(c, d, b)
        if (d1 * d2 < 0 && d3 * d4 < 0)
            return 0
        const toSegment = (p, q, r) => {
            const dx = r.px - q.px, dy = r.py - q.py
            const length2 = dx * dx + dy * dy
            const t = length2 > 0 ? Math.max(0, Math.min(1, ((p.px - q.px) * dx + (p.py - q.py) * dy) / length2)) : 0
            return Math.hypot(p.px - (q.px + t * dx), p.py - (q.py + t * dy))
        }
        return Math.min(toSegment(a, c, d), toSegment(b, c, d), toSegment(c, a, b), toSegment(d, a, b))
    }

    // Borunun kenar çizgisinin kalınlığı (px)
    function edgeWidth(tube: real): real {
        return Math.max(1, Math.min(2.5, tube * 0.06))
    }

    // Borunun bir noktadaki kesiti (yolu hazırlar): boru göze ne kadar dönükse o kadar
    // yuvarlak bir elips; ekrana paralel boruda düz bir çizgi.
    function crossSection(ctx, p, radius: real, fromAngle: real, toAngle: real) {
        ctx.save()
        ctx.translate(p.px, p.py)
        ctx.rotate(Math.atan2(p.ty, p.tx))
        ctx.scale(Math.max(0.001, p.steep), 1)
        ctx.beginPath()
        ctx.arc(0, 0, radius, fromAngle, toAngle)
        ctx.restore()
    }

    // Bir şeridi çiz. Gövde, borunun iki kenarı arasındaki çokgendir; kenarlar ayrı
    // çizgilerdir, parıltı en üsttedir. İki şerit aynı kesitte birleşir; dolgu sınırda
    // 1.5 px taşar: hangisi önce çizilirse çizilsin dikiş görünmez. Uçlarda kesitin
    // dışa bakan yarısının kenarı çizilir (yandan bakınca uç düz, önden bakınca yuvarlak).
    function paintRun(ctx, points, run, tube: real, fogOf) {
        const colors = view.tubeColors[run.key]
        const a = run.first, z = run.last
        const freeStart = a === 0, freeEnd = z === points.length - 1
        const half = tube / 2
        const edge = view.edgeWidth(tube)
        const start = points[a], end = points[z]

        // Uzaklığa göre solan renk: şeridin başından sonuna yumuşak geçiş
        const faded = (color, strength) => {
            const c0 = view.mix(color, view.background, strength * fogOf(start.depth))
            const c1 = view.mix(color, view.background, strength * fogOf(end.depth))
            if (Math.hypot(end.px - start.px, end.py - start.py) < 0.5)
                return c0
            const gradient = ctx.createLinearGradient(start.px, start.py, end.px, end.py)
            gradient.addColorStop(0, c0)
            gradient.addColorStop(1, c1)
            return gradient
        }

        // 1) Gövde
        const extension = 1.5
        const shiftAt = v => {
            if (v === a && !freeStart)
                return { x: -start.tx * extension, y: -start.ty * extension }
            if (v === z && !freeEnd)
                return { x: end.tx * extension, y: end.ty * extension }
            return { x: 0, y: 0 }
        }
        ctx.beginPath()
        for (let v = a; v <= z; ++v) {
            const p = points[v], shift = shiftAt(v)
            const x = p.px + p.nx * half + shift.x, y = p.py + p.ny * half + shift.y
            if (v === a)
                ctx.moveTo(x, y)
            else
                ctx.lineTo(x, y)
        }
        for (let v = z; v >= a; --v) {
            const p = points[v], shift = shiftAt(v)
            ctx.lineTo(p.px - p.nx * half + shift.x, p.py - p.ny * half + shift.y)
        }
        ctx.closePath()
        ctx.fillStyle = faded(colors.fill, 0.35)
        ctx.fill()

        // 2) Kenarlar: borunun iki yanı ve uçlardaki kesitin dışa bakan yarısı
        ctx.lineCap = "round"
        ctx.lineJoin = "round"
        ctx.lineWidth = edge
        ctx.strokeStyle = faded(colors.edge, 0.2)
        for (const sign of [1, -1]) {
            ctx.beginPath()
            for (let v = a; v <= z; ++v) {
                const p = points[v]
                const x = p.px + sign * p.nx * half, y = p.py + sign * p.ny * half
                if (v === a)
                    ctx.moveTo(x, y)
                else
                    ctx.lineTo(x, y)
            }
            ctx.stroke()
        }
        if (freeStart) {
            view.crossSection(ctx, start, half, Math.PI / 2, 3 * Math.PI / 2)
            ctx.strokeStyle = view.mix(colors.edge, view.background, 0.2 * fogOf(start.depth))
            ctx.stroke()
        }
        if (freeEnd) {
            view.crossSection(ctx, end, half, -Math.PI / 2, Math.PI / 2)
            ctx.strokeStyle = view.mix(colors.edge, view.background, 0.2 * fogOf(end.depth))
            ctx.stroke()
        }

        // 3) Parıltı (ince borularda çizilmez); uçlardan taşmasın diye kısa kesilir
        if (tube >= 8) {
            const width = tube * 0.22
            const inset = (p, sign) => ({ x: p.shineX + sign * p.tx * width * 0.6, y: p.shineY + sign * p.ty * width * 0.6 })
            const first = freeStart ? inset(start, 1) : { x: start.shineX, y: start.shineY }
            const last = freeEnd ? inset(end, -1) : { x: end.shineX, y: end.shineY }
            ctx.lineWidth = width
            ctx.strokeStyle = faded(colors.shine, 0.35)
            ctx.beginPath()
            ctx.moveTo(first.x, first.y)
            for (let v = a + 1; v < z; ++v)
                ctx.lineTo(points[v].shineX, points[v].shineY)
            ctx.lineTo(last.x, last.y)
            ctx.stroke()
        }
    }

    Canvas {
        id: canvas

        objectName: "partCanvas"
        anchors.fill: parent
        anchors.margins: 1 // çerçevenin içinde kalsın
        antialiasing: true

        onPaint: view.paintScene(canvas.getContext("2d"))
        onVisibleChanged: view.repaint()
        onWidthChanged: view.repaint()
        onHeightChanged: view.repaint()
    }

    // Adım numarası rozetleri: borunun üstünde, her zaman okunur. ROTASYON adımının
    // rozetinde ↻ işareti vardır. Renk, adımın durumunu gösterir (işlenen adım turuncu).
    Repeater {
        model: view.labels

        delegate: Rectangle {
            id: badge

            required property int index
            required property var modelData

            readonly property var spot: badge.index < view.badgeSpots.length ? view.badgeSpots[badge.index] : null
            readonly property var colors: view.tubeColors[view.stateOf(badge.modelData.step)]

            objectName: "badge" + (badge.modelData.step + 1)
            visible: badge.spot !== null
            x: badge.spot ? badge.spot.x - badge.width / 2 : 0
            y: badge.spot ? badge.spot.y - badge.height / 2 : 0
            width: Math.max(22, badgeText.implicitWidth + 12)
            height: 22
            radius: 11
            color: badge.colors.badge
            border.width: 1.5
            border.color: badge.colors.badgeEdge

            Text {
                id: badgeText

                anchors.centerIn: parent
                text: (badge.modelData.command === BendProgram.Rotate ? "↻" : "") + (badge.modelData.step + 1)
                font.pixelSize: 12
                font.bold: true
                color: badge.colors.badgeText
            }
        }
    }

    // Sürükleyerek döndür: sağa sürükleyince parça sağa, aşağı sürükleyince üstü öne döner.
    DragHandler {
        id: dragger

        property real startAzimuth: 0
        property real startElevation: 0
        property point startPosition

        target: null
        onActiveChanged: {
            if (dragger.active) {
                presetAnimation.stop()
                dragger.startAzimuth = view.azimuth
                dragger.startElevation = view.elevation
                dragger.startPosition = dragger.centroid.position
                view.preset = ""
            }
        }
        onCentroidChanged: {
            if (!dragger.active)
                return
            const dx = dragger.centroid.position.x - dragger.startPosition.x
            const dy = dragger.centroid.position.y - dragger.startPosition.y
            view.azimuth = dragger.startAzimuth - dx * 0.4
            view.elevation = Math.max(-90, Math.min(90, dragger.startElevation + dy * 0.4))
        }
    }

    // Hazır bakışlar: sağ üstte, alt alta
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 6

        PresetButton {
            objectName: "viewTop"
            name: "top"
            text: qsTr("ÜST")
        }

        PresetButton {
            objectName: "viewSide"
            name: "side"
            text: qsTr("YAN")
        }

        PresetButton {
            objectName: "view3d"
            name: "3d"
            text: qsTr("3B")
        }
    }

    Text {
        objectName: "partEmpty"
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 40)
        visible: view.pieceCount === 0
        text: qsTr("Program boş: çizilecek parça yok.")
        font.pixelSize: Theme.fontNormal
        color: Theme.textMuted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
    }

    // Üretimde renklerin anlamı
    Row {
        objectName: "partLegend"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.bottomMargin: 7
        spacing: 14
        visible: view.production && view.pieceCount > 0

        LegendItem {
            colorKey: "normal"
            text: qsTr("Bitti")
        }

        LegendItem {
            colorKey: "current"
            text: qsTr("İşleniyor")
        }

        LegendItem {
            colorKey: "remaining"
            text: qsTr("Sırada")
        }
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 12
        anchors.bottomMargin: 6
        visible: view.pieceCount > 0 && !view.production
        text: qsTr("Döndürmek için sürükleyin")
        font.pixelSize: 12
        color: Theme.textMuted
    }

    // Hazır bakış butonu: seçili olan koyu dolu görünür.
    component PresetButton: Rectangle {
        id: presetButton

        required property string name
        required property string text

        width: 52
        height: 40
        radius: Theme.radius
        color: view.preset === presetButton.name ? Theme.navSelected
                                                  : (presetTap.pressed ? Theme.buttonDown : Theme.buttonFace)
        border.color: view.preset === presetButton.name ? Theme.navSelected : Theme.panelBorder
        visible: view.pieceCount > 0

        Text {
            anchors.centerIn: parent
            text: presetButton.text
            font.pixelSize: 14
            font.bold: true
            color: view.preset === presetButton.name ? "white" : Theme.text
        }

        TapHandler {
            id: presetTap

            onTapped: view.showPreset(presetButton.name)
        }
    }

    // Açıklama: renkli kare ve anlamı
    component LegendItem: Row {
        id: legendItem

        required property string colorKey
        required property string text

        spacing: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 3
            color: view.tubeColors[legendItem.colorKey].fill
            border.color: view.tubeColors[legendItem.colorKey].edge
        }

        Text {
            text: legendItem.text
            font.pixelSize: 12
            font.bold: true
            color: Theme.textMuted
        }
    }
}
