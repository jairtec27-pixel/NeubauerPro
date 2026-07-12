import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

// MARK: - Extensiones
extension String {
    var soloEnteros: String { self.filter { "0123456789".contains($0) } }
    var soloDecimales: String {
        var tienePunto = false
        return self.filter { caracter in
            if caracter.isNumber { return true }
            if caracter == "." {
                if tienePunto { return false }
                tienePunto = true
                return true
            }
            return false
        }
    }
}

// MARK: - Lógica Principal (ViewModel)
class NeubauerViewModel: ObservableObject {
    @Published var nombreCultivo: String = ""
    
    // Variables Stock y Dilución
    @Published var volResuspension: String = ""
    @Published var alicuotaUL: String = ""
    @Published var tripanoUL: String = ""
    
    // Cuadrantes Cámara A y B
    @Published var a1: String = ""; @Published var a2: String = ""
    @Published var a3: String = ""; @Published var a4: String = ""
    @Published var b1: String = ""; @Published var b2: String = ""
    @Published var b3: String = ""; @Published var b4: String = ""
    
    // Viabilidad Opcional
    @Published var muertasA: String = ""
    @Published var muertasB: String = ""
    
    // Gestor de Siembra
    @Published var wellsToSeed: String = ""
    @Published var cellsPerWell: String = ""
    @Published var volumePerWell_uL: String = ""
    @Published var marginVolume_mL: String = ""
    
    // Cálculos Derivados
    var conteosValidos: [Double] {
        [a1, a2, a3, a4, b1, b2, b3, b4].compactMap { Double($0) }
    }
    
    var conteosCamaraAString: String {
        [a1, a2, a3, a4].filter { !$0.isEmpty }.joined(separator: ", ")
    }
    
    var conteosCamaraBString: String {
        [b1, b2, b3, b4].filter { !$0.isEmpty }.joined(separator: ", ")
    }
    
    var promedioPorCuadro: Double {
        guard !conteosValidos.isEmpty else { return 0 }
        return conteosValidos.reduce(0, +) / Double(conteosValidos.count)
    }
    
    var factorDilucion: Double {
        let al = Double(alicuotaUL) ?? 0
        let tr = Double(tripanoUL) ?? 0
        guard al > 0 else { return 1 }
        return (al + tr) / al
    }
    
    var coeficienteVariacion: Double {
        guard conteosValidos.count > 1, promedioPorCuadro > 0 else { return 0 }
        let sumaDiferenciasCuadrado = conteosValidos.map { pow($0 - promedioPorCuadro, 2) }.reduce(0, +)
        let varianza = sumaDiferenciasCuadrado / Double(conteosValidos.count - 1)
        return (sqrt(varianza) / promedioPorCuadro) * 100
    }
    
    var cellsPerML: Double {
        return promedioPorCuadro * factorDilucion * 10_000
    }
    
    var totalCellsAvailable: Double {
        let vol = Double(volResuspension) ?? 0
        return cellsPerML * vol
    }
    
    var viabilidadCalculada: Double? {
        guard !muertasA.isEmpty || !muertasB.isEmpty else { return nil }
        let mA = Double(muertasA) ?? 0
        let mB = Double(muertasB) ?? 0
        let vivas = conteosValidos.reduce(0, +)
        let total = vivas + mA + mB
        guard total > 0 else { return 0 }
        return (vivas / total) * 100
    }
    
    var maxPozosCapacidad: Int {
        let cPW = Double(cellsPerWell) ?? 0
        guard cPW > 0 else { return 0 }
        return Int(totalCellsAvailable / cPW)
    }
    
    var targetConcentration_CellsPerML: Double {
        let cPW = Double(cellsPerWell) ?? 0
        let vol_uL = Double(volumePerWell_uL) ?? 0
        guard vol_uL > 0 else { return 0 }
        let vol_mL = vol_uL / 1000.0
        return cPW / vol_mL
    }
    
    var requiredVolume_mL: Double {
        let wells = Double(wellsToSeed) ?? 0
        let volWell_uL = Double(volumePerWell_uL) ?? 0
        let margin_mL = Double(marginVolume_mL) ?? 0
        return (wells * (volWell_uL / 1000.0)) + margin_mL
    }
    
    var requiredCells: Double {
        return requiredVolume_mL * targetConcentration_CellsPerML
    }
    
    var stockToTake_mL: Double {
        guard cellsPerML > 0 else { return 0 }
        return requiredCells / cellsPerML
    }
    
    var mediumToAdd_mL: Double {
        let medio = requiredVolume_mL - stockToTake_mL
        return medio > 0 ? medio : 0
    }
    
    func limpiarSesion() {
        nombreCultivo = ""
        volResuspension = ""; alicuotaUL = ""; tripanoUL = ""
        a1 = ""; a2 = ""; a3 = ""; a4 = ""
        b1 = ""; b2 = ""; b3 = ""; b4 = ""
        muertasA = ""; muertasB = ""
        wellsToSeed = ""; cellsPerWell = ""; volumePerWell_uL = ""; marginVolume_mL = ""
    }
    
    var tieneDatosSinGuardar: Bool {
        return !conteosValidos.isEmpty || !volResuspension.isEmpty
    }
    
    var canCalculateSeeding: Bool {
        return !(wellsToSeed.isEmpty || cellsPerWell.isEmpty || volumePerWell_uL.isEmpty || marginVolume_mL.isEmpty) && requiredCells > 0
    }
}

// MARK: - Funciones Universales de Formato
func formatoNum(_ numero: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return f.string(from: NSNumber(value: numero)) ?? "0"
}

func formatoCientifico(_ numero: Double) -> String {
    if numero == 0 { return "0.00" }
    
    let str = String(format: "%.2e", numero)
    let partes = str.split(separator: "e")
    guard partes.count == 2 else { return str }
    
    let base = String(partes[0])
    let exponenteInt = Int(partes[1]) ?? 0
    let expStr = String(exponenteInt)
    
    let superscripts: [Character: String] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"
    ]
    
    let exponenteSuper = expStr.map { superscripts[$0] ?? String($0) }.joined()
    return "\(base) × 10\(exponenteSuper)"
}

// MARK: - Componente de Animación "Count-up"
struct AnimatableNumber: View, Animatable {
    var value: Double
    var formatter: (Double) -> String
    
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    
    var body: some View {
        Text(formatter(value))
    }
}

// MARK: - App Principal
struct ContentView: View {
    @StateObject private var vm = NeubauerViewModel()
    @State private var enBienvenida = true
    
    var body: some View {
        Group {
            if enBienvenida {
                PantallaBienvenida(vm: vm, enBienvenida: $enBienvenida)
            } else {
                PantallaPrincipal(vm: vm)
            }
        }
        .frame(minWidth: 1400, minHeight: 900)
    }
}

// MARK: - Pantalla de Bienvenida
struct PantallaBienvenida: View {
    @ObservedObject var vm: NeubauerViewModel
    @Binding var enBienvenida: Bool
    
    // Estados para el movimiento fluido (no binario)
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 1. Fondo Deep Navy base
            Color(red: 0.05, green: 0.05, blue: 0.15).edgesIgnoringSafeArea(.all)
            
            // 2. Fondo Fluido (Circles Blur) - Sin saltos ni choques
            Circle()
                .fill(Color.blue.opacity(0.2))
                .blur(radius: 120)
                .offset(x: offset1, y: offset2)
                .onAppear {
                    withAnimation(.linear(duration: 15).repeatForever(autoreverses: true)) {
                        offset1 = 200
                        offset2 = 150
                    }
                }
            
            Circle()
                .fill(Color.purple.opacity(0.2))
                .blur(radius: 100)
                .offset(x: -offset1, y: -offset2)
                .onAppear {
                    withAnimation(.linear(duration: 20).repeatForever(autoreverses: true)) {
                        offset1 = -150
                        offset2 = 200
                    }
                }
            
            // Capa de contenido (fija y estable)
            VStack(spacing: 30) {
                Spacer()
                Image(systemName: "microbe.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("Bienvenido a Neubauer Pro")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                
                Text("Configura tu nueva sesión de conteo celular.")
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Nombre del Experimento / Cultivo").font(.headline).foregroundColor(.white)
                    
                    TextField("Ej. Ensayo de viabilidad - Fibroblastos L929", text: $vm.nombreCultivo)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .frame(width: 450)
                        .onSubmit {
                            if vm.nombreCultivo.isEmpty { vm.nombreCultivo = "Sesión sin título" }
                            withAnimation { enBienvenida = false }
                        }
                }
                .padding(.top, 20)
                
                Button(action: {
                    if vm.nombreCultivo.isEmpty { vm.nombreCultivo = "Sesión sin título" }
                    withAnimation { enBienvenida = false }
                }) {
                    Text("Comenzar Sesión")
                        .font(.title2.bold())
                        .padding(.horizontal, 40)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.top, 20)
                .keyboardShortcut(.defaultAction)
                
                Spacer()
                
                // Footer
                Text("Neubauer Pro © 2026 | Creado por Q.I. Jair A. Temis Cortina | Impulsado por Gemini Pro")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.bottom, 20)
            }
        }
    }
}
// MARK: - Pantalla Principal (Dashboard)
struct PantallaPrincipal: View {
    @ObservedObject var vm: NeubauerViewModel
    @State private var mostrarResumen = false
    @State private var mostrarInfoReglas = false
    @State private var mostrarAlertaLimpiar = false
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .edgesIgnoringSafeArea(.all)
            
            WindowDelegateController(hasUnsavedChanges: vm.tieneDatosSinGuardar)
                .frame(width: 0, height: 0)
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "microbe.fill").font(.title2).foregroundColor(.blue)
                    Text("Neubauer Pro").font(.title2.bold())
                    Text("|").foregroundColor(.gray).padding(.horizontal, 8)
                    Text("Sesión actual:").foregroundColor(.secondary)
                    TextField("Nombre del cultivo...", text: $vm.nombreCultivo)
                        .textFieldStyle(.plain).font(.headline)
                    Spacer()
                    
                    Button(action: { mostrarAlertaLimpiar = true }) {
                        Label("Limpiar Datos", systemImage: "trash").font(.headline)
                    }
                    .buttonStyle(.bordered).tint(.red)
                    .alert(isPresented: $mostrarAlertaLimpiar) {
                        Alert(
                            title: Text("¿Limpiar todos los datos?"),
                            message: Text("Esta acción no se puede deshacer. Asegúrate de haber guardado o exportado tu PDF antes de borrar la sesión actual."),
                            primaryButton: .destructive(Text("Borrar todo")) {
                                withAnimation { vm.limpiarSesion() }
                            },
                            secondaryButton: .cancel(Text("Cancelar"))
                        )
                    }
                }
                .padding()
                .background(Color.black.opacity(0.2))
                
                HStack(alignment: .top, spacing: 40) {
                    
                    // --- COLUMNA IZQUIERDA ---
                    VStack(spacing: 18) {
                        
                        GroupBox {
                            HStack(spacing: 15) {
                                InputView(titulo: "Vol. Resuspensión (mL)", texto: $vm.volResuspension, decimal: true)
                                InputView(titulo: "Alícuota (µL)", texto: $vm.alicuotaUL, decimal: true)
                                InputView(titulo: "Azul Tripano (µL)", texto: $vm.tripanoUL, decimal: true)
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Factor Dilución").font(.caption).foregroundColor(.secondary)
                                    Text(String(format: "%.2f", vm.factorDilucion))
                                        .font(.title3.bold()).foregroundColor(.blue)
                                        .frame(height: 32)
                                }
                            }
                            .padding(.top, 5)
                        } label: {
                            SectionHeader(icon: "testtube.2", title: "Preparación de Muestra", color: .gray)
                        }
                        
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Patrón de conteo utilizado").font(.caption).bold().foregroundColor(.secondary)
                                HStack(spacing: 15) {
                                    MiniNeubauerMap()
                                    Text("Se recomienda 1 mm² por cuadrante.").font(.caption2).foregroundColor(.gray)
                                }
                            }
                            Spacer()
                            Button(action: { mostrarInfoReglas.toggle() }) {
                                Image(systemName: "info.circle.fill").foregroundColor(.blue).font(.title3)
                                Text("Reglas de Conteo")
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $mostrarInfoReglas) { ReglasConteoTooltip() }
                        }
                        
                        HStack(spacing: 20) {
                            ChamberGrid(title: "Cámara A", q1: $vm.a1, q2: $vm.a2, q3: $vm.a3, q4: $vm.a4)
                            ChamberGrid(title: "Cámara B", q1: $vm.b1, q2: $vm.b2, q3: $vm.b3, q4: $vm.b4)
                        }
                        
                        // ALERTA DE CV CON TRANSICIÓN SLIDE/FADE
                        if vm.conteosValidos.count > 1 {
                            HStack {
                                let cv = vm.coeficienteVariacion
                                if cv <= 15 {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Text("Conteo consistente (CV: \(String(format: "%.1f", cv))%)").foregroundColor(.green)
                                } else if cv <= 25 {
                                    Image(systemName: "info.circle.fill").foregroundColor(.orange)
                                    Text("Variación normal entre cuadrantes (CV: \(String(format: "%.1f", cv))%)").foregroundColor(.orange)
                                } else {
                                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.red)
                                    Text("Diferencias elevadas entre cuadrantes (CV: \(String(format: "%.1f", cv))%). Se recomienda verificar el conteo.").foregroundColor(.red)
                                }
                            }
                            .font(.subheadline).bold()
                            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                            .background((vm.coeficienteVariacion <= 15 ? Color.green : (vm.coeficienteVariacion <= 25 ? Color.orange : Color.red)).opacity(0.1))
                            .cornerRadius(8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        GroupBox {
                            HStack(spacing: 30) {
                                InputView(titulo: "Muertas Cámara A", texto: $vm.muertasA, decimal: false)
                                InputView(titulo: "Muertas Cámara B", texto: $vm.muertasB, decimal: false)
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Viabilidad Calculada").font(.caption).foregroundColor(.secondary)
                                    if let viab = vm.viabilidadCalculada {
                                        Text("\(String(format: "%.1f", viab))%")
                                            .font(.title3.bold())
                                            .foregroundColor(viab >= 80 ? .green : .red)
                                    } else {
                                        Text("No evaluada").font(.headline).foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.top, 5)
                        } label: {
                            SectionHeader(icon: "heart.slash", title: "Viabilidad (Opcional)", color: .gray)
                        }
                        
                        GroupBox {
                            HStack {
                                ResultDisplay(
                                    title: "Concentración",
                                    value: vm.cellsPerML,
                                    formatterMain: { formatoCientifico($0) },
                                    formatterSub: { "\(formatoNum($0)) cél/mL" },
                                    color: .blue,
                                    isLarge: true
                                )
                                Spacer()
                                ResultDisplay(
                                    title: "Total Disponible",
                                    value: vm.totalCellsAvailable,
                                    formatterMain: { formatoCientifico($0) },
                                    formatterSub: { "\(formatoNum($0)) células" },
                                    color: .green,
                                    isLarge: true
                                )
                            }
                            .padding(.vertical, 8)
                        } label: {
                            SectionHeader(icon: "star.fill", title: "Resultados Principales", color: .yellow)
                        }
                        
                        GroupBox {
                            HStack {
                                ResultDisplay(
                                    title: "Promedio",
                                    value: vm.promedioPorCuadro,
                                    formatterMain: { String(format: "%.1f", $0) },
                                    formatterSub: { _ in "cél/cuadro" },
                                    color: .indigo,
                                    isLarge: false
                                )
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Capacidad Estimada").font(.caption).foregroundColor(.secondary)
                                    if vm.maxPozosCapacidad > 0 {
                                        Text("\(vm.maxPozosCapacidad) pozos").font(.title3.bold()).foregroundColor(.purple)
                                        Text("de \(formatoNum(Double(vm.cellsPerWell) ?? 0)) cél").font(.caption2).foregroundColor(.gray)
                                    } else {
                                        Text("-").font(.title3.bold()).foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 5)
                        } label: {
                            SectionHeader(icon: "list.bullet.clipboard", title: "Métricas Adicionales", color: .gray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(.easeInOut(duration: 0.4), value: vm.conteosValidos.count)
                    .animation(.easeInOut(duration: 0.5), value: vm.cellsPerML)
                    
                    Divider()
                    
                    // --- COLUMNA DERECHA ---
                    VStack(spacing: 25) {
                        GroupBox {
                            VStack(spacing: 15) {
                                HStack {
                                    InputView(titulo: "Pozos a sembrar", texto: $vm.wellsToSeed, decimal: false)
                                    InputView(titulo: "Células/pozo", texto: $vm.cellsPerWell, decimal: false)
                                }
                                HStack {
                                    InputView(titulo: "Vol. de pozo (µL)", texto: $vm.volumePerWell_uL, decimal: true)
                                    InputView(titulo: "Vol. de Excedente (mL)", texto: $vm.marginVolume_mL, decimal: true)
                                }
                                
                                if vm.canCalculateSeeding {
                                    let suficiente = vm.totalCellsAvailable >= vm.requiredCells
                                    VStack(alignment: .leading, spacing: 14) {
                                        HStack {
                                            Text(suficiente ? "✓ Stock suficiente" : "✗ Stock insuficiente")
                                                .font(.title3.bold()).foregroundColor(suficiente ? .green : .red)
                                            Spacer()
                                            Text("Req: \(formatoCientifico(vm.requiredCells)) cél").font(.subheadline).foregroundColor(.secondary)
                                        }
                                        
                                        if suficiente {
                                            Divider()
                                            
                                            // LÓGICA DE SOBREDILUCIÓN ESTRICTA CORREGIDA
                                            let sobrediluida = vm.cellsPerML < vm.targetConcentration_CellsPerML
                                            
                                            if sobrediluida {
                                                // ALERTA DE SOBREDILUCIÓN CON TRANSICIÓN
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text("⚠️ Muestra sobrediluida: La concentración actual no permite alcanzar la densidad requerida para el volumen del pozo. Acción sugerida: Centrifugar nuevamente el stock y resuspender en un volumen menor.")
                                                        .font(.subheadline)
                                                        .fontWeight(.bold)
                                                        .foregroundColor(.orange)
                                                }
                                                .padding()
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.orange.opacity(0.15))
                                                .cornerRadius(8)
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange, lineWidth: 1.5))
                                                .transition(.move(edge: .top).combined(with: .opacity))
                                                
                                            } else {
                                                HStack {
                                                    Text("Vol. Final (Incl. \(vm.marginVolume_mL)mL Excedente):").font(.headline).foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(String(format: "%.2f", vm.requiredVolume_mL)) mL").font(.title2.bold())
                                                }
                                                HStack {
                                                    Text("1. Tomar Stock:").font(.title3).foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(String(format: "%.4f", vm.stockToTake_mL)) mL")
                                                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.blue)
                                                }
                                                HStack {
                                                    Text("2. Agregar Medio:").font(.title3).foregroundColor(.secondary)
                                                    Spacer()
                                                    Text("\(String(format: "%.4f", vm.mediumToAdd_mL)) mL")
                                                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.blue)
                                                }
                                                
                                                // ESQUEMA BIORENDER (COMO APOYO VISUAL EXTRA LIMPIO)
                                                Image("EsquemaSiembra")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(maxHeight: 280)
                                                    .overlay(
                                                        GeometryReader { geo in
                                                            Text("\(String(format: "%.4f", vm.stockToTake_mL))")
                                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                                .foregroundColor(.black)
                                                                .minimumScaleFactor(0.5)
                                                                .position(x: geo.size.width * 0.366, y: geo.size.height * 0.062)
                                                            
                                                            Text("\(String(format: "%.4f", vm.mediumToAdd_mL))")
                                                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                                                .foregroundColor(.black)
                                                                .minimumScaleFactor(0.5)
                                                                .position(x: geo.size.width * 0.387, y: geo.size.height * 0.940)
                                                        }
                                                    )
                                                    .padding(.top, 15)
                                                    .transition(.opacity) // Fade in para la imagen
                                            }
                                        }
                                    }
                                    .padding(15).background(Color.gray.opacity(0.1)).cornerRadius(8)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                } else if !(vm.wellsToSeed.isEmpty && vm.cellsPerWell.isEmpty && vm.volumePerWell_uL.isEmpty && vm.marginVolume_mL.isEmpty) {
                                    Text("Por favor, llena todos los campos de siembra (incluyendo el Volumen de Excedente) para calcular la preparación.")
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                        .padding()
                                }
                            }
                            .padding(.top, 5)
                            .animation(.easeInOut(duration: 0.4), value: vm.canCalculateSeeding)
                        } label: {
                            SectionHeader(icon: "flask.fill", title: "Gestor de Siembra", color: .purple)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(30)
                
                Spacer()
                
                Button(action: { mostrarResumen = true }) {
                    Text("Guardar Sesión")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .sheet(isPresented: $mostrarResumen) {
            ResumenSheetView(vm: vm, isPresented: $mostrarResumen)
        }
    }
}

// MARK: - Componentes de Interfaz

struct SectionHeader: View {
    var icon: String; var title: String; var color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
        }
        .padding(.bottom, 6)
    }
}

struct MiniNeubauerMap: View {
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        let esEsquina = (row == 0 || row == 2) && (col == 0 || col == 2)
                        Rectangle()
                            .fill(esEsquina ? Color.blue.opacity(0.3) : Color.gray.opacity(0.1))
                            .frame(width: 15, height: 15)
                            .border(Color.gray.opacity(0.4), width: 1)
                            .overlay(Text(esEsquina ? "X" : "").font(.system(size: 8, weight: .bold)).foregroundColor(.blue))
                    }
                }
            }
        }
    }
}

struct ReglasConteoTooltip: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reglas de Conteo (1 mm²)").font(.headline)
            Text("Ingrese el número TOTAL de células contadas en un cuadro grande de la esquina.")
            Divider()
            HStack { Image(systemName: "checkmark.circle.fill").foregroundColor(.green); Text("Contar borde superior e izquierdo") }
            HStack { Image(systemName: "xmark.circle.fill").foregroundColor(.red); Text("No contar borde inferior y derecho") }
        }
        .padding().frame(width: 280)
    }
}

struct InputView: View {
    var titulo: String; @Binding var texto: String; var decimal: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(titulo).font(.caption).foregroundColor(.secondary)
            TextField("0", text: $texto)
                .textFieldStyle(.roundedBorder)
                .onChange(of: texto) { oldValue, newValue in texto = decimal ? newValue.soloDecimales : newValue.soloEnteros }
        }
    }
}

struct ChamberGrid: View {
    var title: String
    @Binding var q1: String; @Binding var q2: String
    @Binding var q3: String; @Binding var q4: String
    var body: some View {
        VStack {
            Text(title).font(.headline).foregroundColor(.indigo)
            VStack(spacing: 6) {
                HStack(spacing: 6) { QuadrantInput(text: $q1); QuadrantInput(text: $q2) }
                HStack(spacing: 6) { QuadrantInput(text: $q3); QuadrantInput(text: $q4) }
            }
            .padding(10).background(Color.white.opacity(0.8)).cornerRadius(12)
        }
    }
}

struct QuadrantInput: View {
    @Binding var text: String
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { _ in HStack(spacing: 0) { ForEach(0..<4, id: \.self) { _ in Rectangle().stroke(Color.gray.opacity(0.15), lineWidth: 0.5) } } }
            }
            TextField("", text: $text)
                .textFieldStyle(.plain).multilineTextAlignment(.center)
                .font(.system(.title, design: .monospaced))
                .foregroundColor(.black)
                .onChange(of: text) { oldValue, newValue in text = newValue.soloDecimales }
        }
        .frame(width: 70, height: 70)
        .background(Color.white).cornerRadius(4)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
    }
}

struct ResultDisplay: View {
    var title: String
    var value: Double
    var formatterMain: (Double) -> String
    var formatterSub: (Double) -> String
    var color: Color
    var isLarge: Bool = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(isLarge ? .headline : .caption).foregroundColor(.secondary)
            
            AnimatableNumber(value: value, formatter: formatterMain)
                .font(.system(isLarge ? .largeTitle : .title2, design: .monospaced).bold())
                .foregroundColor(color)
            
            AnimatableNumber(value: value, formatter: formatterSub)
                .font(isLarge ? .subheadline : .caption2)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Hoja de Resumen y PDF

struct ResumenSheetView: View {
    @ObservedObject var vm: NeubauerViewModel
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Vista Previa del Reporte").font(.largeTitle.bold())
            
            ReportePDFView(vm: vm)
                .padding(40)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(radius: 5)
                .frame(width: 700, height: 750)
            
            HStack(spacing: 20) {
                Button("Cancelar") { isPresented = false }
                    .buttonStyle(.bordered)
                
                Button(action: exportarAPDF) {
                    Label("Exportar PDF", systemImage: "doc.text.fill")
                }
                .buttonStyle(.bordered)
                .tint(.purple)
                
                Button(action: { isPresented = false }) {
                    Label("Guardar y Finalizar", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(.bottom, 20)
        }
        .frame(width: 800, height: 900)
        .padding()
    }
    
    @MainActor
    func exportarAPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.title = "Guardar Reporte Neubauer"
        panel.message = "Elige dónde guardar tu reporte de conteo celular."
        panel.nameFieldStringValue = "Reporte_\(vm.nombreCultivo.replacingOccurrences(of: " ", with: "_")).pdf"
        
        if panel.runModal() == .OK, let url = panel.url {
            let vistaAImprimir = ReportePDFView(vm: vm).frame(width: 612, height: 792)
            let renderer = ImageRenderer(content: vistaAImprimir)
            
            renderer.render { size, context in
                var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
                guard let pdfContext = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
                pdfContext.beginPDFPage(nil)
                context(pdfContext)
                pdfContext.endPDFPage()
                pdfContext.closePDF()
            }
        }
    }
}

struct ReportePDFView: View {
    @ObservedObject var vm: NeubauerViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("NEUBAUER PRO").font(.system(size: 24, weight: .bold))
                Text("Reporte de Conteo Celular").font(.title3).foregroundColor(.gray)
                HStack {
                    ReporteFila(lbl: "Fecha", val: Date().formatted(date: .numeric, time: .omitted))
                    Spacer()
                    ReporteFila(lbl: "Sesión", val: vm.nombreCultivo)
                }
                .padding(.top, 10)
            }
            
            Divider().background(Color.black)
            
            HStack(alignment: .top, spacing: 40) {
                VStack(alignment: .leading, spacing: 25) {
                    ReporteSeccion(titulo: "PREPARACIÓN DE MUESTRA") {
                        ReporteFila(lbl: "Volumen de resuspensión", val: "\(vm.volResuspension) mL")
                        ReporteFila(lbl: "Alícuota", val: "\(vm.alicuotaUL) µL")
                        ReporteFila(lbl: "Azul tripano", val: "\(vm.tripanoUL) µL")
                        ReporteFila(lbl: "Factor de dilución", val: String(format: "%.1f", vm.factorDilucion))
                    }
                    
                    ReporteSeccion(titulo: "CONTEO") {
                        ReporteFila(lbl: "Cámara A", val: vm.conteosCamaraAString.isEmpty ? "-" : vm.conteosCamaraAString)
                        ReporteFila(lbl: "Cámara B", val: vm.conteosCamaraBString.isEmpty ? "-" : vm.conteosCamaraBString)
                        ReporteFila(lbl: "Promedio", val: "\(String(format: "%.1f", vm.promedioPorCuadro)) cél/cuadro")
                        ReporteFila(lbl: "CV", val: "\(String(format: "%.1f", vm.coeficienteVariacion)) %")
                    }
                    
                    if let viab = vm.viabilidadCalculada {
                        ReporteSeccion(titulo: "VIABILIDAD") {
                            ReporteFila(lbl: "Muertas Cámara A", val: vm.muertasA.isEmpty ? "0" : vm.muertasA)
                            ReporteFila(lbl: "Muertas Cámara B", val: vm.muertasB.isEmpty ? "0" : vm.muertasB)
                            ReporteFila(lbl: "Viabilidad", val: "\(String(format: "%.1f", viab)) %")
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 25) {
                    ReporteSeccion(titulo: "RESULTADOS PRINCIPALES") {
                        ReporteFila(lbl: "Concentración", val: "\(formatoCientifico(vm.cellsPerML)) cél/mL")
                        ReporteFila(lbl: "Total disponible", val: "\(formatoCientifico(vm.totalCellsAvailable)) células")
                        
                        let capStr = vm.maxPozosCapacidad > 0 ? "\(vm.maxPozosCapacidad) pozos de \(formatoNum(Double(vm.cellsPerWell) ?? 0)) cél" : "-"
                        ReporteFila(lbl: "Capacidad estimada", val: capStr)
                    }
                    
                    if vm.canCalculateSeeding {
                        ReporteSeccion(titulo: "GESTOR DE SIEMBRA") {
                            ReporteFila(lbl: "Pozos", val: vm.wellsToSeed)
                            ReporteFila(lbl: "Células por pozo", val: formatoNum(Double(vm.cellsPerWell) ?? 0))
                            ReporteFila(lbl: "Volumen por pozo", val: "\(vm.volumePerWell_uL) µL")
                            ReporteFila(lbl: "Vol. de excedente", val: "\(vm.marginVolume_mL) mL")
                            
                            Spacer().frame(height: 10)
                            
                            // LÓGICA STRICTA DE CORRECCIÓN APLICADA AQUÍ TAMBIÉN
                            if vm.cellsPerML < vm.targetConcentration_CellsPerML {
                                Text("⚠️ Muestra sobrediluida: La concentración actual no permite alcanzar la densidad requerida para el volumen del pozo. Acción sugerida: Centrifugar nuevamente el stock y resuspender en un volumen menor.")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.red)
                            } else {
                                ReporteFila(lbl: "Volumen final", val: "\(String(format: "%.2f", vm.requiredVolume_mL)) mL")
                                ReporteFila(lbl: "Tomar stock", val: "\(String(format: "%.4f", vm.stockToTake_mL)) mL")
                                ReporteFila(lbl: "Agregar medio", val: "\(String(format: "%.4f", vm.mediumToAdd_mL)) mL")
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(30)
        .foregroundColor(.black)
    }
}

struct ReporteSeccion<Content: View>: View {
    var titulo: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(titulo).font(.system(size: 14, weight: .bold)).tracking(1)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

struct ReporteFila: View {
    var lbl: String; var val: String
    var body: some View {
        HStack(alignment: .top) {
            Text("\(lbl):").font(.system(size: 13))
            Spacer()
            Text(val).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - INTERCEPTOR DE VENTANA
struct WindowDelegateController: NSViewRepresentable {
    var hasUnsavedChanges: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.delegate = context.coordinator
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.hasUnsavedChanges = hasUnsavedChanges
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(hasUnsavedChanges: hasUnsavedChanges)
    }
    
    class Coordinator: NSObject, NSWindowDelegate {
        var hasUnsavedChanges: Bool
        
        init(hasUnsavedChanges: Bool) {
            self.hasUnsavedChanges = hasUnsavedChanges
        }
        
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            if hasUnsavedChanges {
                let alert = NSAlert()
                alert.messageText = "Datos no guardados"
                alert.informativeText = "Tienes datos en los cuadrantes. ¿Seguro que quieres cerrar la aplicación? Perderás todo si no has exportado tu PDF."
                alert.addButton(withTitle: "Cancelar (Quedarme)")
                alert.addButton(withTitle: "Cerrar sin guardar")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    return false
                } else {
                    return true
                }
            }
            return true
        }
    }
}

#Preview {
    ContentView()
}

