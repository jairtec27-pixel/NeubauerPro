# Neubauer Pro: Estandarización Algorítmica y Control de Calidad en Modelos de Siembra Celular *In Vitro*

Este repositorio contiene el código fuente de **Neubauer Pro**, una aplicación diseñada bajo principios de bioinformática clínica y desarrollo de software médico para la optimización de flujos de trabajo en laboratorios de cultivo celular. El sistema actúa como un entorno de validación determinista que elimina la variabilidad operativa e instrumental durante las etapas críticas de conteo y siembra celular.

---

## 1. Objetivo del Software

El propósito fundamental de **Neubauer Pro** es erradicar por completo el **error humano** latente en los cálculos manuales de densidad y dilución celular. En la investigación científica contemporánea, la reproducibilidad técnica es un pilar indispensable; sin embargo, los métodos tradicionales basados en transcripciones en bitácoras y cálculos manuales introducen desviaciones significativas debido a errores de redondeo, fatiga operativa y sesgos de criterio bajo la campana de flujo laminar.

Esta herramienta estandariza rigurosamente el proceso completo a través de una arquitectura de software modular que guía al operador en dos fases consecutivas:
1. **Cuantificación digitalizada** de biomasa mediante el registro por cuadrantes en la cámara de Neubauer.
2. **Modelado matemático predictivo** para la gestión volumétrica de la siembra en placas multipozo.

Esta estandarización es de vital importancia en ensayos *in vitro* de alta precisión, tales como la **evaluación fisicoquímica y biológica de biomateriales y biopolímeros avanzados**. Al asegurar que la densidad inicial de siembra sobre modelos de fibroblastos y queratinocitos sea matemáticamente idéntica entre réplicas, la aplicación garantiza que las cinéticas de proliferación, migración y reparación tisular observadas respondan exclusivamente a las propiedades del estímulo biológico y no a artefactos metodológicos.

---

## 2. Metodología Matemática

La aplicación ejecuta un motor de cálculo síncrono fundamentado en principios clásicos de la fisicoquímica de soluciones. Los algoritmos centrales implementan las siguientes ecuaciones analíticas:

### Determinación de la Concentración Base ($C_1$)
Para determinar la densidad celular del stock original, el sistema recopila los conteos de los cuadrantes periféricos ($1 \text{ mm}^2$ cada uno) de las cámaras A y B para calcular la concentración molecular por unidad de volumen a través de la siguiente relación formal:

$$C_1 = \bar{N} \times FD \times 10^4 \text{ células/mL}$$

Donde:
* $\bar{N}$ representa el **promedio aritmético de células** contadas por cuadro grande analizado.
* $FD$ es el **Factor de Dilución** automatizado a partir de las variables físicas de la alícuota y el agente de contraste (Azul de Tripano), definido por:

$$FD = \frac{V_{\text{alícuota}} + V_{\text{tripano}}}{V_{\text{alícuota}}}$$

* $10^4$ corresponde al **factor de conversión volumétrico** estándar de la cámara de Neubauer, derivado de la constante física del volumen sobre cada cuadrante ($0.1 \text{ mm}^3 = 10^{-4} \text{ mL}$).

### Conservación de Masa en la Preparación de la Siembra
Para la transición del estado de stock a la fase de experimentación multipozo, la aplicación aplica estrictamente la ecuación de continuidad de masa para soluciones ideales:

$$C_1 V_1 = C_2 V_2$$

El algoritmo resuelve para el **Volumen de Stock celular requerido** ($V_1$), calculando previamente las necesidades biológicas del sistema receptor mediante las siguientes igualdades:

* **Concentración Meta ($C_2$):** Densidad celular necesaria por unidad de volumen final para cumplir con la densidad por pozo.

$$C_2 = \frac{\text{Células por pozo}}{V_{\text{pozo (mL)}}}$$

* **Volumen Final del Ensayo ($V_2$):** Integra el requerimiento nominal de la placa y la variable de control del volumen muerto.

$$V_2 = (N_{\text{pozos}} \times V_{\text{pozo (mL)}}) + V_{\text{excedente}}$$

A partir de estas constantes, el software evalúa y despliega vectorialmente en la interfaz:
1. **Volumen de Stock a Pipetear ($V_1$):** $V_1 = (C_2 \times V_2) / C_1$
2. **Volumen de Medio de Cultivo Complementario ($V_{\text{medio}}$):** $V_{\text{medio}} = V_2 - V_1$

---

## 3. Gestión Lógica y Escenarios de Error Contemplados

El núcleo de **Neubauer Pro** opera como una máquina de estados finitos que valida en tiempo real la viabilidad física del experimento antes de permitir la ejecución de cualquier protocolo de preparación, implementando tres candados lógicos principales:

### A. Prevención de División entre Cero
El motor de cálculo cuenta con un sistema de desempaquetado seguro (`conditional unwrapping`). Si el usuario interactúa con los campos del Gestor de Siembra sin haber ingresado valores numéricos en los cuadrantes de conteo, el sistema captura la interrupción lógica, asigna un estado base controlado ($0.0$) y bloquea el procesamiento matemático río abajo, impidiendo excepciones de tiempo de ejecución (`runtime panics`) o resultados indefinidos ($\infty$).

### B. Bloqueo por Faltante Celular (Stock Insuficiente)
Antes de autorizar el cálculo volumétrico, el algoritmo evalúa la biomasa total disponible frente a la demanda agregada del diseño experimental a través de la siguiente inecuación condicional:

$$(C_1 \times V_{\text{resuspensión}}) \ge (C_2 \times V_2)$$

Si esta condición se evalúa como falsa, el software suspende dinámicamente la generación de la guía de preparación y activa un estado de alerta prioritario de **"Stock Insuficiente"**, detallando el déficit numérico absoluto para que el investigador reajuste las dimensiones de la placa o el número de pozos.

### C. Identificación Estricta de Sobredilución
Este candado detecta cuando la muestra se encuentra en un estado físico donde es matemáticamente imposible alcanzar la concentración requerida, debido a que la concentración del stock inicial es estrictamente menor a la concentración meta por pozo ($C_1 < C_2$). En términos computacionales clásicos, esto generaría un volumen de stock necesario mayor al volumen total del tubo ($V_1 > V_2$), resultando en un volumen de medio negativo ($V_{\text{medio}} < 0$).

Para evitar este sinsentido experimental, el sistema implementa la siguiente validación condicional estricta:

    let sobrediluida = vm.cellsPerML < vm.targetConcentration_CellsPerML

    if sobrediluida {
        // 1. Ocultar instrucciones nominales de pipeteo
        // 2. Ocultar el esquema gráfico de los tubos guía
        // 3. Renderizar bloque de alerta visual de alta prioridad
    }

Al activarse esta bandera, la interfaz se transforma inmediatamente para mostrar el siguiente dictamen técnico unificado:

> ⚠️ Muestra sobrediluida: La concentración actual no permite alcanzar la densidad requerida para el volumen del pozo. Acción sugerida: Centrifugar nuevamente el stock y resuspender en un volumen menor.

---

## 4. Impacto en la Integridad de Resultados

Desde la perspectiva de la gobernanza de datos y la integridad científica, **Neubauer Pro** eleva los estándares del laboratorio al transformar una actividad artesanal en un proceso auditable y reproducible:

* **Minimización del Coeficiente de Variación ($CV$):** Al incorporar alertas automáticas cuando la variación entre cuadrantes supera el límite tolerable ($CV > 25\%$), la aplicación actúa como un filtro de control de calidad estadístico que detecta malas distribuciones celulares o errores de pipeteo en la cámara antes de proceder con el ensayo.
* **Homogeneidad de Confluencia:** Al calcular el volumen basándose estrictamente en la densidad por unidad de volumen ajustada al **Volumen de Excedente**, se garantiza de forma matemática que el pozo número 1 y el pozo número 24 reciban exactamente la misma masa celular, logrando monocapas confluentes idénticas.
* **Trazabilidad Científica:** La capacidad integrada de exportar cada sesión a un reporte formal en formato PDF (estructurado a doble columna bajo formato de reporte de bitácora) permite anexar documentación técnica transparente a los cuadernos de trabajo impresos o digitales, satisfaciendo las auditorías más estrictas de comités académicos y agencias de indexación internacional.
