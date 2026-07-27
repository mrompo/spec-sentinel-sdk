# Spec Sentinel SDK
## 1. Visión y Principios Base
Este framework adopta el paradigma de *Spec Driven Development* utilizando `open-spec` como fuente única de verdad. El objetivo es orquestar un ecosistema de IA donde el código generado se adhiera estrictamente a las especificaciones definidas, garantizando coherencia arquitectónica (por ejemplo, en la transición y mantenimiento de un monolito modular). La IA actúa como un copiloto y orquestador que no solo asiste en la escritura, sino que opera dentro de un marco predecible, repetible y auditable para todos los equipos.

## 2. Límites y Guardarraíles (Guardrails)
Para asegurar la calidad, la seguridad y el control, la IA operará bajo restricciones inquebrantables:
* **Restricciones Arquitectónicas:** Obligación de respetar estructuras de carpetas predefinidas, gestión de autenticación centralizada y patrones de diseño.
* **Límites de Ejecución (Safety Limits):** Prohibición estricta de ejecutar comandos destructivos en el sistema de archivos o bases de datos sin confirmación humana explícita.
* **Aislamiento de Entornos:** La IA solo interactuará con entornos contenerizados (Docker/Docker Swarm) durante la evaluación local, sin ningún tipo de acceso a credenciales o variables de producción.
* **Validación Cruzada:** Todo fragmento de código debe ser validado de forma cruzada contra el documento `open-spec` antes de generar un *commit* en Git.

## 3. Definición de Subagentes
El trabajo de desarrollo se distribuye entre subagentes especializados, cada uno con un contexto delimitado para evitar alucinaciones:
* **Spec-Agent (Orquestador):** Encargado de leer, interpretar y fragmentar los archivos de `open-spec` en requerimientos técnicos procesables para el resto de agentes.
* **Backend-Agent (Lógica):** Especializado en la escritura de lógica de negocio pura, gestión de bases de datos relacionales (MySQL, SQLite) y manejo de eventos/colas (Kafka).
* **Ops-Agent (Infraestructura):** Responsable de generar y verificar las configuraciones de red, contenedores, y políticas de API Gateway (ej. Kong).
* **Tooling-Agent (Integración):** Enfocado en la creación de utilidades secundarias, como aplicaciones CLI para automatizar la sincronización de datos entre plataformas de gestión de proyectos e incidencias.

## 4. Habilidades y Herramientas (Skills)
Los subagentes tendrán acceso a herramientas específicas (*skills*) que extienden sus capacidades de forma segura:
* **Repo-Sync:** Capacidad para clonar, indexar dependencias, navegar por el árbol de directorios y estructurar *commits* semánticos.
* **Spec-Parser:** Herramientas para analizar y validar esquemas de gobierno de datos y mapas de APIs contra la especificación en tiempo real.
* **Sandbox-Exec:** Capacidad para ejecutar pruebas unitarias o linters dentro de contenedores aislados, retroalimentando a la IA con los errores de compilación o ejecución.
* **CLI-Runner:** Permiso para invocar y parametrizar asistentes de terminal de terceros o scripts internos definidos en el entorno de desarrollo.

## 5. Flujo de Trabajo y Ciclo de Vida
El desarrollo asistido seguirá un ciclo de vida estrictamente canalizado por el framework:
1. **Ingesta y Mapeo:** El framework absorbe la especificación técnica en `open-spec` y mapea las dependencias necesarias.
2. **Delegación Atómica:** El *Spec-Agent* divide el trabajo en tareas atómicas y las distribuye a los subagentes (Backend, Ops, Tooling).
3. **Implementación Restringida:** Los subagentes escriben el código respetando los *guardrails* de arquitectura.
4. **Validación Autónoma:** El sistema ejecuta el código generado en el sandbox mediante *Sandbox-Exec*, verificando que cumpla con las especificaciones iniciales.
5. **Revisión Humana:** El desarrollador líder revisa el paquete consolidado antes de integrarlo formalmente en el repositorio principal, cerrando el bucle.
framework_context.md
Mostrando framework_context.md.