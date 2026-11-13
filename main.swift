// TouchPet: un animaletto che vive nella Touch Bar e reagisce a come scrivi.
// Sta nella Control Strip (a destra); toccandolo la barra si espande e lui ha spazio per correre.
import AppKit
import ServiceManagement

// MARK: - Umore (logica pura, verificata da --selftest)

enum Mood: String { case sleeping = "dorme", idle = "fermo", walking = "cammina", running = "corre", frantic = "frenetico", angry = "arrabbiato" }

/// rate = tasti al secondo (media degli ultimi secondi), idle = secondi dall'ultimo tasto, anger = vedi angerAfter
func mood(rate: Double, idle: Double, anger: Double) -> Mood {
    if anger >= 5 { return .angry }
    if idle > 30 { return .sleeping }
    if rate < 0.5 { return .idle }
    if rate < 4 { return .walking }
    if rate < 6 { return .running } // 6 tasti/s ≈ 70 parole al minuto, tenuti per qualche secondo
    return .frantic
}

/// Media mobile esponenziale: l'animale non scatta a ogni singolo tasto, accelera e rallenta piano.
func smoothed(_ old: Double, instant: Double, dt: Double) -> Double {
    old + (instant - old) * min(1, dt / 2.5)
}

/// Rabbia da Backspace: +1 a ogni pressione, +3 al secondo tenendolo premuto, −1 al secondo sempre.
/// A 5 si arrabbia (circa 5 Backspace di fila o 2 secondi tenuto) e la rabbia sale a 8, così resta arrabbiato 3 secondi.
func angerAfter(_ anger: Double, pressed: Bool, held: Bool, dt: Double) -> Double {
    let a = max(0, anger - dt) + (pressed ? 1 : 0) + (held ? 3 * dt : 0)
    return a >= 5 && anger < 5 ? 8 : min(8, a)
}

// MARK: - Disegni (pixel art, l'animale guarda a destra)
// '#' pelo, 'd' pelo scuro (zampe dietro, strisce), 'l' pelo chiaro (pancia, muso), 'o' occhio, '-' occhio chiuso,
// 'w' bianco, 'p' rosa, 'a' arancione, 'k' grigio, 'r' rosso, 'y' giallo, 'g' verde, '.' vuoto

struct Species {
    let name: String
    let color: Int          // colore tipico del pelo, 0xRRGGBB
    let top: [[String]]     // testa e coda: due varianti, alternate da fermo (scodinzola o muove un orecchio)
    let body: [String]
    let legs: [[String]]    // fermo, passo aperto, passo chiuso
    let sleep: [String]
    let hat: (col: Int, row: Int)       // dove appoggia l'accessorio: colonna centrale e riga della cima della testa
    let sleepHat: (col: Int, row: Int)  // lo stesso nel disegno addormentato
    let hop: Int            // pixel di saltello a ogni passo (il coniglio salta, gli altri no)
}

let quadrupedLegs = [
    ["..##.dd....##.dd....",
     "..##.dd....##.dd....",
     "..ll.dd....ll.dd...."],
    ["..##.dd...dd.##.....",
     ".##...dd.dd...##....",
     ".ll...dd.dd...ll...."],
    ["...##dd....d##......",
     "...##d.....d##......",
     "...lld.....dll......"],
]

let speciesList = [
    Species(name: "Gatto", color: 0xF29A38,
            top: [["..............#...#.",
                   ".............#p#.#p#",
                   "dd...........#######",
                   ".##..........#o###o#",
                   "..#..........##lpl##",
                   "..#...........#lll#."],
                  ["..............#...#.",
                   ".............#p#.#p#",
                   ".............#######",
                   ".............#o###o#",
                   "d............##lpl##",
                   ".##...........#lll#."]],
            body: ["..################..",
                   "..###d##d##d#####...",
                   "..###############...",
                   "..##lllllllllll##..."],
            legs: quadrupedLegs,
            sleep: ["..............#...#.",
                    "....########.#p#.#p#",
                    "..###d##d##d########",
                    ".#############-###-#",
                    ".##############lpl##",
                    "dd#############lll#.",
                    ".ddd###lllllll####.."],
            hat: (16, 2), sleepHat: (16, 2), hop: 0),
    Species(name: "Cane", color: 0xB9824E,
            top: [["....................",
                   "..............####..",
                   "l............d#####.",
                   "##...........dd#o##.",
                   ".#...........dd###ld",
                   ".##...........d##lll"],
                  ["....................",
                   "..............####..",
                   "..l..........d#####.",
                   "..#..........dd#o##.",
                   "..#..........dd###ld",
                   "..#...........d##lll"]],
            body: ["..################..",
                   "..###############...",
                   "..###############...",
                   "..##lllllllllll##..."],
            legs: quadrupedLegs,
            sleep: ["....#########.......",
                    "..############d###..",
                    ".#############dd-##.",
                    "l#############dd##ld",
                    ".###lllllll####llll."],
            hat: (16, 1), sleepHat: (16, 1), hop: 0),
    Species(name: "Coniglio", color: 0xE4E4EA,
            top: [["..............##.##.",
                   "..............#p.#p.",
                   "..............#p.#p.",
                   ".............#######",
                   ".............#o###o#",
                   ".............##lpl##"],
                  ["..............##....",
                   "..............#p.##.",
                   "..............#p.#p.",
                   ".............#######",
                   ".............#o###o#",
                   ".............##lpl##"]],
            body: ["......########llll#.",
                   "....##############..",
                   "..ll##############..",
                   "..ll#############...",
                   "....##lllllllll##..."],
            legs: [["....####....##......",
                    "....lllll...ll......"],
                   ["...###........##....",
                    "..lll..........ll..."],
                   ["......####.##.......",
                    "......lllll.ll......"]],
            sleep: ["..............#..#..",
                    "....#########.#p.#p.",
                    "..##################",
                    ".#############-###-#",
                    "ll#############lpl##",
                    "ll####lllllll##lll#."],
            hat: (16, 0), sleepHat: (16, 0), hop: 1),
    Species(name: "Papera", color: 0xFFD83D,
            top: [["...........####...",
                   "..........######..",
                   "..........###o##aa",
                   "..........######a.",
                   "#..........####..."],
                  ["...........####...",
                   "..........######..",
                   "..........###o##aa",
                   "..........######a.",
                   "...........####..."]],
            body: ["##.....########...",
                   "###############...",
                   ".##ddddd######l...",
                   ".###ddd######ll...",
                   "..###########l....",
                   "...#########......"],
            legs: [["......a..a........",
                    "......aa.aa......."],
                   [".....a....a.......",
                    "....aa....aa......"],
                   [".......aa.........",
                    ".......aaa........"]],
            sleep: ["..........####....",
                    "#........##-###a..",
                    "##.....#########..",
                    "###############...",
                    ".##ddddd######l...",
                    ".###ddd######ll...",
                    "..###########l....",
                    "...#########......"],
            hat: (13, 0), sleepHat: (12, 0), hop: 0),
    Species(name: "Elefante", color: 0x9AA3B0,
            top: [["............######....",
                   "...##########dd####...",
                   "..##########dddd#o##..",
                   ".###########dddd######",
                   "d###########dddd###.##",
                   "d############dd###w.##"],
                  ["............######....",
                   "...###########d####...",
                   "..###########ddd#o##..",
                   ".############ddd######",
                   "d############ddd###.##",
                   "d############dd###w.##"]],
            body: [".################ww.##",
                   ".###############...##.",
                   ".###############..##..",
                   ".##lllllllllll##......"],
            legs: [["..###.ddd.###ddd......",
                    "..###.ddd.###ddd......",
                    "..lll.ddd.lllddd......"],
                   ["..###.ddd.ddd###......",
                    ".###...dddddd..###....",
                    ".lll...dddddd..lll...."],
                   ["...###dd...d###.......",
                    "...###d....d###.......",
                    "...llld....dlll......."]],
            sleep: ["............######....",
                    "...##########dd####...",
                    "..##########dddd#-##..",
                    ".###########dddd######",
                    "d###########dddd##ww##",
                    "d##lllllllll#####..###"],
            hat: (15, 0), sleepHat: (15, 0), hop: 0),
    Species(name: "Coccodrillo", color: 0x5FA04E,
            top: [["................##........",
                   "..d.d.d.d.d.d..#o#########",
                   "..########################"],
                  ["................##........",
                   "...d.d.d.d.d.d.#o#########",
                   "..########################"]],
            body: ["##################w#w#w#w.",
                   ".####lllllllllll#########."],
            legs: [["...##.dd......##.dd.......",
                    "...ll.dd......ll.dd......."],
                   ["..##...dd....dd...##......",
                    "..ll...dd....dd...ll......"],
                   ["....##d........d##........",
                    "....lld........dll........"]],
            sleep: ["................##........",
                    "..d.d.d.d.d.d..#-#########",
                    "##########################",
                    ".####lllllllllll#########."],
            hat: (17, 0), sleepHat: (17, 0), hop: 0),
    Species(name: "Pinguino", color: 0x3F4C6B,
            top: [["....#####.....",
                   "...#######....",
                   "...###wow#aa..",
                   "...##wwww#a...",
                   "...##wwww#...."],
                  ["....#####.....",
                   "...#######....",
                   "...###wow#aa..",
                   "...##wwww#....",
                   "...##wwww#...."]],
            body: ["..###wwwww#...",
                   ".d###wwwww##..",
                   ".d##wwwwww##..",
                   ".d##wwwwww##..",
                   "..##wwwwww##..",
                   "...##wwww##..."],
            legs: [["....aa..aa....",
                    "...aaa.aaa...."],
                   ["...aa....aa...",
                    "..aaa...aaa..."],
                   [".....aa.aa....",
                    "....aaaaaa...."]],
            sleep: ["....#####.....",
                    "...#######....",
                    "...###w-w#aa..",
                    "..###wwww##...",
                    ".d##wwwwww##..",
                    ".d##wwwwww##..",
                    "..##wwwwww##..",
                    "...########..."],
            hat: (6, 0), sleepHat: (6, 0), hop: 0),
    Species(name: "Tartaruga", color: 0x7BC47A,
            top: [["......dddddd........",
                   "....dd#dd#dddd..###.",
                   "...dd#dddd#dddd.#o##",
                   "..dddddddddddddd####"],
                  ["......dddddd........",
                   "....dd#dd#dddd......",
                   "...dd#dddd#dddd###..",
                   "..dddddddddddddd#o#."]],
            body: [".#llllllllllllll##..",
                   "..llllllllllllll...."],
            legs: [["...##.......##......",
                    "...##.......##......"],
                   ["..##.........##.....",
                    "..##.........##....."],
                   ["....##.....##.......",
                    "....##.....##......."]],
            sleep: ["......dddddd........",
                    "....dd#dd#dddd......",
                    "...dd#dddd#dddd.....",
                    "..dddddddddddddd-#..",
                    "..llllllllllllll...."],
            hat: (17, 1), sleepHat: (9, 0), hop: 0),
]

let accessories: [(name: String, rows: [String])] = [
    ("Nessuno", []),
    ("Cilindro", ["..kkk..",
                  "..kkk..",
                  "..rrr..",
                  ".kkkkk."]),
    ("Corona", ["y.y.y",
                "yyyyy",
                "yryry"]),
    ("Fiocco", ["rr.rr",
                ".rrr.",
                "rr.rr"]),
    ("Fiore", [".p.",
               "pyp",
               ".p.",
               ".g."]),
]
let heart = [".r.r.",
             "rrrrr",
             ".rrr.",
             "..r.."]
let angerMark = ["rr.rr",
                 "r...r",
                 ".....",
                 "r...r",
                 "rr.rr"]

func color(hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func hex(of color: NSColor) -> Int? {
    guard let c = color.usingColorSpace(.sRGB) else { return nil }
    return Int((c.redComponent * 255).rounded()) << 16 | Int((c.greenComponent * 255).rounded()) << 8 | Int((c.blueComponent * 255).rounded())
}

/// I colori di tutti i simboli dei disegni, ricavati dal colore del pelo.
func palette(_ fur: NSColor) -> [Character: NSColor] {
    let darkFur = (fur.usingColorSpace(.sRGB)?.brightnessComponent ?? 1) < 0.35
    let eye = darkFur ? NSColor.systemYellow : NSColor.black // su un pelo scuro gli occhi neri sparirebbero
    return ["#": fur,
            "d": fur.blended(withFraction: 0.35, of: darkFur ? .white : .black) ?? fur,
            "l": fur.blended(withFraction: 0.6, of: .white) ?? fur,
            "o": eye, "-": eye,
            "p": color(hex: 0xFF8FA8), "a": color(hex: 0xFF8A1F), "k": color(hex: 0x70707A),
            "w": .white, "r": color(hex: 0xF0384A), "y": color(hex: 0xFFD21F), "g": color(hex: 0x4CC25A)]
}

func drawSprite(_ rows: [String], x: CGFloat, y: CGFloat, px: CGFloat, flipped: Bool, palette: [Character: NSColor]) {
    for (r, row) in rows.enumerated() {
        for (c, ch) in row.enumerated() {
            guard let color = palette[ch] else { continue }
            let col = flipped ? row.count - 1 - c : c
            // AppKit ha l'origine in basso: la riga 0 del disegno va in alto
            let cell = NSRect(x: x + CGFloat(col) * px, y: y + CGFloat(rows.count - 1 - r) * px, width: px, height: px)
            if ch == "-" { // occhio chiuso: una fessura alta mezzo pixel sopra il pelo
                palette["#"]?.setFill(); cell.fill()
                color.setFill(); NSRect(x: cell.minX, y: cell.minY, width: px, height: px / 2).fill()
            } else {
                color.setFill(); cell.fill()
            }
        }
    }
}

// MARK: - Aspetto scelto dall'utente (salvato nelle preferenze)

struct Look {
    var species = 0, accessory = 0
    var color: NSColor? // nil = colore tipico dell'animale

    static func load() -> Look {
        let d = UserDefaults.standard
        // i valori salvati potrebbero essere di una versione con più animali: li riporto nei limiti
        return Look(species: min(max(d.integer(forKey: "species"), 0), speciesList.count - 1),
                    accessory: min(max(d.integer(forKey: "accessory"), 0), accessories.count - 1),
                    color: (d.object(forKey: "color") as? Int).map(color(hex:)))
    }
    func save() {
        let d = UserDefaults.standard
        d.set(species, forKey: "species")
        d.set(accessory, forKey: "accessory")
        d.set(color.flatMap(hex(of:)), forKey: "color") // nil cancella la chiave
    }
}
@MainActor var look = Look.load()

// MARK: - Vista dell'animale

final class PetView: NSView {
    let roams: Bool // true = cammina avanti e indietro (barra espansa); false = resta sul posto
    let px: CGFloat // lato di un pixel del disegno, in punti (1,5 nella barra = 3 pixel veri dello schermo)
    var onTap: (() -> Void)?
    var mood = Mood.idle
    var time = 0.0
    var phase = 0.0 // avanza di 1 a ogni passo
    private var petUntil = -1.0
    private var x: CGFloat = 0
    private var dir: CGFloat = 1

    init(roams: Bool, px: CGFloat) {
        self.roams = roams
        self.px = px
        super.init(frame: .zero)
        allowedTouchTypes = .direct // senza questo la Touch Bar non manda i tocchi alla vista
    }
    required init?(coder: NSCoder) { fatalError() }

    override func touchesBegan(with event: NSEvent) { onTap?() }
    override func mouseDown(with event: NSEvent) { onTap?() }

    var petted: Bool { time < petUntil }
    func pet() { petUntil = time + 1.5 }
    private var moving: Bool { [.walking, .running, .frantic].contains(mood) && !petted }

    func tick(_ dt: Double, mood: Mood, rate: Double) {
        self.mood = mood
        time += dt
        if moving {
            // passi e velocità crescono in modo continuo e dolce con i tasti al secondo (fino a 12)
            let r = min(rate, 12)
            phase += dt * (3 + r * 0.6)
            if roams {
                x += dir * r * 10 * dt
                let maxX = bounds.width - CGFloat(speciesList[look.species].body[0].count) * px
                if x > maxX { x = maxX; dir = -1 }
                if x < 0 { x = 0; dir = 1 }
            }
        }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let sp = speciesList[look.species]
        let pal = palette(look.color ?? color(hex: sp.color))
        let sleeping = mood == .sleeping && !petted
        let step = moving ? Int(phase) % 2 : 0

        var rows = sp.sleep, hat = sp.sleepHat
        if !sleeping {
            var top = sp.top[mood == .idle && !petted ? Int(time * 2) % 2 : 0]
            if petted || time.truncatingRemainder(dividingBy: 4) < 0.25 { // occhi chiusi: felice, oppure battito ogni 4 secondi
                top = top.map { $0.replacingOccurrences(of: "o", with: "-") }
            }
            rows = top + sp.body + sp.legs[moving ? 1 + step : 0]
            hat = sp.hat
        }

        let cols = rows[0].count
        var ox = roams ? x : (bounds.width - CGFloat(cols) * px) / 2
        var oy = max(1, (bounds.height - 20 * px) / 2) // 20 righe: l'animale più alto con il cappello e il salto
        if moving, step == 0 { oy += CGFloat(sp.hop + (mood == .walking ? 0 : 1)) * px } // saltella sul passo aperto
        if petted { oy += CGFloat(abs(sin(time * 9))) * 2 * px } // salta di gioia
        if mood == .angry, !petted { ox += (Int(time * 16) % 2 == 0 ? px : -px) / 3 } // trema
        // arrotondati al pixel vero dello schermo (mezzo punto sui Retina): fuori griglia i quadratini sfumano e compaiono righe
        let scale = window?.backingScaleFactor ?? 2
        ox = (ox * scale).rounded() / scale
        oy = (oy * scale).rounded() / scale

        let flipped = dir < 0
        drawSprite(rows, x: ox, y: oy, px: px, flipped: flipped, palette: pal)
        let headY = oy + CGFloat(rows.count - hat.row) * px // cima della testa
        let headX = ox + CGFloat(flipped ? cols - hat.col : hat.col) * px
        let acc = accessories[look.accessory].rows
        if !acc.isEmpty {
            let left = hat.col - acc[0].count / 2
            drawSprite(acc, x: ox + CGFloat(flipped ? cols - left - acc[0].count : left) * px, y: headY, px: px, flipped: flipped, palette: pal)
        }

        // effetti: "dietro" è il lato della coda, "davanti" quello del muso
        let back: CGFloat = flipped ? 1 : -1
        let behindX = headX + (flipped ? 4 : -9) * px, frontX = headX + (flipped ? -9 : 4) * px
        if sleeping {
            let p = time.truncatingRemainder(dividingBy: 2) / 2 // la "z" sale e svanisce ogni 2 secondi
            ("z" as NSString).draw(at: NSPoint(x: behindX + back * p * 3 * px, y: headY - px + p * 4 * px), withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: (5 + p * 2) * px),
                .foregroundColor: NSColor.white.withAlphaComponent(1 - p),
            ])
        }
        if petted { // due cuoricini che salgono ai lati della testa
            for (i, hx) in [behindX, frontX].enumerated() {
                let q = (time * 1.5 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                drawSprite(heart, x: hx, y: headY - 3 * px + q * 4 * px, px: px, flipped: false, palette: pal)
            }
        } else if mood == .angry, Int(time * 4) % 2 == 0 { // segno di rabbia che lampeggia
            drawSprite(angerMark, x: behindX, y: headY - 2 * px, px: px, flipped: false, palette: pal)
        }
        if moving, roams, mood != .walking { // scie di velocità dietro la coda
            NSColor.white.withAlphaComponent(0.5).setFill()
            for i in 0..<3 {
                let len = (4 + 4 * CGFloat((time * 6 + Double(i) * 0.4).truncatingRemainder(dividingBy: 1))) * px
                NSRect(x: flipped ? ox + CGFloat(cols + 3) * px : ox - 3 * px - len, y: oy + CGFloat(2 + 3 * i) * px,
                       width: len, height: max(1, px / 2)).fill()
            }
        }
        if moving, mood == .frantic { // goccia di sudore che vola via dalla testa
            let p = CGFloat((time * 3).truncatingRemainder(dividingBy: 1))
            NSColor.systemTeal.setFill()
            NSRect(x: headX + back * (4 + p * 5) * px, y: headY - p * 4 * px, width: px, height: 1.5 * px).fill()
        }
    }
}

// MARK: - Immagini (icona dell'app e foglio di controllo dei disegni)

func renderPNG(width: Int, height: Int, to path: String, draw: () -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

/// `--icon file.png`: l'icona 1024×1024, usata da build.sh.
func renderIcon(to path: String) {
    renderPNG(width: 1024, height: 1024, to: path) {
        let box = NSRect(x: 100, y: 100, width: 824, height: 824)
        let shape = NSBezierPath(roundedRect: box, xRadius: 185, yRadius: 185)
        NSGraphicsContext.saveGraphicsState() // ombra sotto il riquadro, come le icone di sistema
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35); shadow.shadowBlurRadius = 24; shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set(); NSColor.black.setFill(); shape.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(starting: color(hex: 0x3A3F5C), ending: color(hex: 0x14151F))!.draw(in: shape, angle: -90)

        let cat = speciesList[0], pal = palette(color(hex: cat.color))
        drawSprite(cat.top[0] + cat.body + cat.legs[0], x: 192, y: 270, px: 32, flipped: false, palette: pal)
        drawSprite(heart, x: 340, y: 590, px: 28, flipped: false, palette: pal)
    }
}

/// `--sheet file.png`: tutti gli animali in tutti gli umori, ingranditi, per controllare i disegni a colpo d'occhio.
@MainActor func renderSheet(to path: String) {
    let moods: [Mood] = [.sleeping, .idle, .walking, .running, .frantic, .angry, .idle] // l'ultimo è "accarezzato"
    let cell = NSSize(width: 210, height: 140)
    renderPNG(width: Int(cell.width) * moods.count, height: Int(cell.height) * speciesList.count, to: path) {
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 4000, height: 4000).fill()
        for s in speciesList.indices {
            look = Look(species: s, accessory: (s + 1) % accessories.count, color: nil) // un accessorio diverso per riga
            for (c, m) in moods.enumerated() {
                let view = PetView(roams: m == .running || m == .frantic, px: 6) // chi corre mostra anche le scie
                view.frame = NSRect(origin: .zero, size: cell)
                view.mood = m
                view.time = 1
                view.phase = Double(c) // passo aperto e passo chiuso a colonne alterne
                if c == moods.count - 1 { view.pet() }
                NSGraphicsContext.saveGraphicsState()
                let move = NSAffineTransform()
                move.translateX(by: CGFloat(c) * cell.width, yBy: CGFloat(speciesList.count - 1 - s) * cell.height)
                move.concat()
                view.draw(view.bounds)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}

/// Mette il disegno su un tasto vero: così la Control Strip gli dà lo stesso sfondo grigio dei tasti di sistema
/// (una vista semplice resta sul grigio più scuro della striscia). I tocchi restano alla vista.
func systemKey(_ view: NSView) -> NSButton {
    let key = NSButton(title: "", target: nil, action: nil)
    view.translatesAutoresizingMaskIntoConstraints = false
    key.addSubview(view)
    NSLayoutConstraint.activate([
        key.widthAnchor.constraint(equalToConstant: 54), // larghezza dei tasti di sistema (luminosità, volume…)
        view.leadingAnchor.constraint(equalTo: key.leadingAnchor), view.trailingAnchor.constraint(equalTo: key.trailingAnchor),
        view.topAnchor.constraint(equalTo: key.topAnchor), view.bottomAnchor.constraint(equalTo: key.bottomAnchor),
    ])
    return key
}

// MARK: - App

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let trayID = NSTouchBarItem.Identifier("local.touchpet.tray")
    let bar = NSTouchBar()
    let trayPet = PetView(roams: false, px: 1.5), barPet = PetView(roams: true, px: 1.5), bigPet = PetView(roams: false, px: 6)
    let barArea = NSView()
    lazy var visibleWidth = barArea.subviews[0].widthAnchor.constraint(equalToConstant: 600)
    var settings: NSWindow?
    let status = NSTextField(labelWithString: "")
    let well = NSColorWell()
    var rate = 0.0, anger = 0.0, backspaceDown = false
    var lastCount = AppDelegate.keyCount
    var last = CACurrentMediaTime(), lastDraw = CACurrentMediaTime()
    // per provarlo senza scrivere: `-rate 8` forza i tasti al secondo, `-rate -1` lo fa dormire
    let forced = UserDefaults.standard.string(forKey: "rate").flatMap(Double.init)

    /// Tasti premuti dall'accesso, contati da macOS: dà la velocità ma non *quali* tasti, quindi non serve alcun permesso.
    static var keyCount: UInt32 { CGEventSource.counterForEventType(.combinedSessionState, eventType: .keyDown) }

    func applicationDidFinishLaunching(_ note: Notification) {
        // 1. l'animale piccolo, sempre visibile nella Control Strip: toccarlo espande la barra
        let tray = NSCustomTouchBarItem(identifier: trayID)
        tray.view = systemKey(trayPet)
        trayPet.onTap = { [unowned self] in expand() }
        NSTouchBarItem.addSystemTrayItem(tray)
        DFRElementSetControlStripPresenceForIdentifier(trayID, true)

        // 2. la barra espansa: l'animale che corre (toccarlo = carezza) e due tasti.
        // Tutto in un solo elemento: con tre elementi separati il sistema nascondeva i tasti per far posto all'animale.
        barPet.onTap = { [unowned self] in barPet.pet() }
        barPet.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let row = NSStackView(views: [
            barPet, // non ha una larghezza sua: si prende tutto lo spazio lasciato dai tasti
            NSButton(title: "Personalizza", target: self, action: #selector(showSettings)),
            NSButton(title: "Esci", target: NSApp, action: #selector(NSApplication.terminate(_:))),
        ])
        // Il sistema non restringe un elemento alla parte di barra libera: quello che sporge resta nascosto.
        // Quindi barArea è largo come l'intera Touch Bar e la riga dentro viene stretta alla parte visibile (vedi tick).
        row.translatesAutoresizingMaskIntoConstraints = false
        barArea.addSubview(row)
        NSLayoutConstraint.activate([
            barArea.widthAnchor.constraint(equalToConstant: 1085),
            row.leadingAnchor.constraint(equalTo: barArea.leadingAnchor),
            row.topAnchor.constraint(equalTo: barArea.topAnchor),
            row.bottomAnchor.constraint(equalTo: barArea.bottomAnchor),
            visibleWidth,
        ])
        let pet = NSCustomTouchBarItem(identifier: .init("pet"))
        pet.view = barArea
        bar.templateItems = [pet]
        bar.defaultItemIdentifiers = [pet.identifier]
        if UserDefaults.standard.bool(forKey: "expand") { expand() } // `-expand YES`: parte già espansa

        Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    /// Aprire di nuovo l'app mentre è già accesa (doppio clic, Spotlight) mostra la finestra di personalizzazione.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return false
    }

    func expand() {
        DFRSystemModalShowsCloseBoxWhenFrontMost(true) // la X a sinistra per richiuderla
        NSTouchBar.presentSystemModalTouchBar(bar, systemTrayItemIdentifier: trayID)
    }

    func tick() {
        let now = CACurrentMediaTime(), dt = now - last
        last = now
        let count = AppDelegate.keyCount
        rate = smoothed(rate, instant: Double(count &- lastCount) / dt, dt: dt) // &- : il contatore può ripartire da zero
        lastCount = count
        // Backspace (tasto 51): chiedo solo "è premuto adesso?", 30 volte al secondo. Anche questo senza permessi.
        let down = CGEventSource.keyState(.combinedSessionState, key: 51)
        anger = angerAfter(anger, pressed: down && !backspaceDown, held: down, dt: dt)
        backspaceDown = down
        var idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        if let forced { rate = max(forced, 0); idle = forced < 0 ? 999 : 0 }
        let m = mood(rate: rate, idle: idle, anger: anger)

        // la parte libera della barra cambia (es. Control Strip aperta o chiusa): la riga la segue
        // Solo a barra espansa: finché la vista non è sullo schermo visibleRect è "infinito", e un valore così
        // rompeva la disposizione (i tasti non comparivano più espandendo dall'icona).
        let visible = barArea.visibleRect.width
        if barArea.window != nil, visible > 0, visible <= barArea.bounds.width, visible != visibleWidth.constant {
            visibleWidth.constant = visible
        }

        let pets = [trayPet, barPet, bigPet]
        // da fermo o addormentato bastano 5 disegni al secondo invece di 30: è sempre acceso, deve consumare poco
        if m == .sleeping || m == .idle, !pets.contains(where: \.petted), now - lastDraw < 0.2 { return }
        pets.forEach { $0.tick(now - lastDraw, mood: m, rate: rate) }
        lastDraw = now
        if settings?.isVisible == true {
            // .formatted usa la virgola in italiano
            status.stringValue = "\(rate.formatted(.number.precision(.fractionLength(1)))) tasti al secondo · \(m.rawValue)"
        }
    }

    // MARK: Finestra di personalizzazione

    @objc func showSettings() {
        if settings == nil { settings = makeSettings() }
        NSApp.activate(ignoringOtherApps: true)
        settings?.makeKeyAndOrderFront(nil)
    }

    func makeSettings() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "TouchPet"
        window.isReleasedWhenClosed = false // chiuderla la nasconde soltanto: l'app continua nella Touch Bar

        // anteprima grande su fondo nero, come nella barra; un clic la accarezza
        bigPet.wantsLayer = true
        bigPet.layer?.backgroundColor = NSColor.black.cgColor
        bigPet.layer?.cornerRadius = 12
        bigPet.onTap = { [unowned self] in bigPet.pet() }
        bigPet.setAccessibilityLabel("Anteprima dell'animale: clicca per accarezzarlo")
        bigPet.heightAnchor.constraint(equalToConstant: 150).isActive = true
        status.textColor = .secondaryLabelColor
        status.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

        let animal = NSPopUpButton() // menu a tendina: otto nomi non stanno in una riga di tasti
        animal.addItems(withTitles: speciesList.map(\.name))
        animal.selectItem(at: look.species)
        animal.target = self
        animal.action = #selector(pickSpecies)
        well.color = look.color ?? color(hex: speciesList[look.species].color)
        well.target = self
        well.action = #selector(pickColor)
        well.widthAnchor.constraint(equalToConstant: 44).isActive = true
        let typical = NSButton(title: "Colore tipico", target: self, action: #selector(resetColor))
        let accessory = NSSegmentedControl(labels: accessories.map(\.name), trackingMode: .selectOne, target: self, action: #selector(pickAccessory))
        accessory.selectedSegment = look.accessory
        let login = NSButton(checkboxWithTitle: "Avvia TouchPet all'accesso", target: self, action: #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Animale:"), animal],
            [NSTextField(labelWithString: "Colore:"), NSStackView(views: [well, typical])],
            [NSTextField(labelWithString: "Accessorio:"), accessory],
            [NSGridCell.emptyContentView, login],
        ])
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        grid.row(at: 1).rowAlignment = .none // il riquadro del colore non ha una linea di base
        grid.row(at: 1).yPlacement = .center
        grid.rowSpacing = 12

        let stack = NSStackView(views: [bigPet, status, grid])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(18, after: status)
        bigPet.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true // largo quanto i controlli sotto
        // margine di 20 punti attorno a tutto: la finestra prende la misura dal contenuto
        let content = NSView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
        ])
        window.contentView = content
        window.center()
        return window
    }

    @objc func pickSpecies(_ sender: NSPopUpButton) {
        look.species = sender.indexOfSelectedItem
        look.save()
        if look.color == nil { well.color = color(hex: speciesList[look.species].color) }
    }
    @objc func pickAccessory(_ sender: NSSegmentedControl) {
        look.accessory = sender.selectedSegment
        look.save()
    }
    @objc func pickColor(_ sender: NSColorWell) {
        look.color = sender.color
        look.save()
    }
    @objc func resetColor() {
        look.color = nil
        look.save()
        well.color = color(hex: speciesList[look.species].color)
    }
    @objc func toggleLogin(_ sender: NSButton) {
        do {
            if sender.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { // macOS ha rifiutato: la casella torna allo stato vero e mostro il motivo
            sender.state = SMAppService.mainApp.status == .enabled ? .on : .off
            NSAlert(error: error).runModal()
        }
    }
}

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if args.contains("--selftest") {
        assert(mood(rate: 9, idle: 31, anger: 0) == .sleeping) // fermo da tanto: dorme anche se la media non è ancora scesa
        assert(mood(rate: 0, idle: 5, anger: 0) == .idle)
        assert(mood(rate: 3, idle: 0, anger: 0) == .walking)
        assert(mood(rate: 5, idle: 0, anger: 0) == .running)
        assert(mood(rate: 6, idle: 0, anger: 0) == .frantic)
        assert(mood(rate: 8, idle: 0, anger: 5) == .angry)
        assert(abs(smoothed(0, instant: 10, dt: 0.25) - 1) < 1e-9) // un decimo del tempo → un decimo della strada
        assert(smoothed(3, instant: 10, dt: 99) == 10) // mai oltre il valore istantaneo

        var a = 0.0 // 4 Backspace rapidi non bastano, il quinto sì; poi resta arrabbiato circa 3 secondi
        for i in 1...5 {
            a = angerAfter(a, pressed: true, held: true, dt: 0.1)
            a = angerAfter(a, pressed: false, held: false, dt: 0.15)
            assert((a >= 5) == (i == 5), "rabbia dopo \(i) Backspace: \(a)")
        }
        assert(angerAfter(a, pressed: false, held: false, dt: 2.5) >= 5 && angerAfter(a, pressed: false, held: false, dt: 3.5) < 5)

        for sp in speciesList { // ogni disegno è un rettangolo e l'accessorio appoggia dentro il disegno
            let width = sp.body[0].count
            let sprites = [sp.sleep] + sp.top.flatMap { t in sp.legs.map { t + sp.body + $0 } }
            assert(sprites.allSatisfy { $0.allSatisfy { $0.count == width } }, "\(sp.name): righe di larghezza diversa")
            assert(sp.top.count == 2 && sp.legs.count == 3, "\(sp.name): servono 2 teste e 3 passi")
            assert((0..<width).contains(sp.hat.col) && (0..<width).contains(sp.sleepHat.col), "\(sp.name): accessorio fuori dal disegno")
        }
        for sprite in accessories.map(\.rows) + [heart, angerMark] {
            assert(sprite.allSatisfy { $0.count == sprite[0].count }, "accessorio con righe di larghezza diversa")
        }
        assert(hex(of: color(hex: 0xF29A38)) == 0xF29A38) // il colore salvato torna identico
        print("selftest ok")
        exit(0)
    }
    if let i = args.firstIndex(of: "--icon"), i + 1 < args.count { renderIcon(to: args[i + 1]); exit(0) }
    if let i = args.firstIndex(of: "--sheet"), i + 1 < args.count { renderSheet(to: args[i + 1]); exit(0) }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // niente icona nel Dock: vive nella Touch Bar
    app.run()
}
