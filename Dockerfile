# En la contruccion de la imagen, "RUN" se usa para preparar la imagen: instalar, compilar, configurar, etc.
# Cuando esta listo el contenedor, "CMD" se usa para decir qué debe hacer el contenedor cuando se ejecuta.

# ---- Base: dependencias de Node ----
# Imagen de version de node.js

FROM node:20-alpine as base 

WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# ---- Desarrollo: ng serve ----
# La primera etapa (base) prepara la imagen con dependencias instaladas.
# La segunda (dev) hereda todo lo anterior y agrega el código fuente + comandos para desarrollo.

FROM base as dev

# Indica que el contenedor “abre” o pone disponible el puerto 4200 para que pueda ser accedido desde fuera del contenedor.
EXPOSE 4200

# Cuando se inicie el contenedor, ejecuta el comando que corre tu app Angular con ciertas configuraciones especiales para Docker.
#| Parte                   | Qué hace                                                                                                                                                                                                               |
#| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
#| `CMD`                   | Define el **comando que se ejecutará automáticamente** cuando el contenedor arranca.                                                                                                                                   |
#| `"npm", "run", "start"` | Llama el script `"start"` definido en tu `package.json` (normalmente `ng serve`).                                                                                                                                      |
#| `"--"`                  | Separa los argumentos del comando npm y los pasa al script que se ejecuta (`ng serve`).                                                                                                                                |
#| `"--host", "0.0.0.0"`   | Hace que el servidor escuche **todas las interfaces de red**, no solo `localhost`. <br>👉 Esto es necesario para poder acceder desde tu navegador fuera del contenedor.                                                |
#| `"--poll=2000"`         | Indica que Angular **verifique cambios en los archivos cada 2 segundos** (2000 ms). <br>Esto se usa porque **Docker no detecta bien los cambios de archivos en tiempo real** en algunos sistemas (como Windows o Mac). |

CMD ["npm", "run", "start", "--", "--host", "0.0.0.0", "--poll=2000"]


# Etapa Build Produccion

FROM base as build 
# | Parte                        | Qué hace                                                                                                   |
# | ---------------------------- | ---------------------------------------------------------------------------------------------------------- |
# | `RUN`                        | Ejecuta un comando **durante el build** de la imagen (no cuando se ejecuta el contenedor).                 |
# | `npm run build`              | Llama al script `"build"` definido en el `package.json`, normalmente algo como: <br>`"build": "ng build"`. |
# | `--`                         | Separa los argumentos que se le pasan a ese script.                                                        |
# | `--configuration=production` | Le dice a Angular que use el **perfil de configuración de producción**, definido en `angular.json`.        |


# Le dice a Angular que use el perfil de configuración de producción, definido en angular.json.
# “Todo lo que venga después de este doble guion (--) son argumentos para el script que vas a ejecutar, no para npm en sí.”
RUN npm run build -- --configuration=production

# ---- Runtime NGINX (SPA) ----
# “Crea una nueva etapa llamada prod basada en la imagen ligera de Nginx 1.27 (Alpine Linux).”

#Angular, React o Vue generan archivos estáticos (HTML, JS, CSS) al hacer el build.
#No necesitan Node.js en producción.
#Por eso se usa Nginx, un servidor web súper rápido, para servir esos archivos.

FROM nginx:1.27-alpine as prod


# Declara una variable disponible solo durante el build (no en tiempo de ejecución del contenedor).
ARG APP_NAME=app

# | Parte                   | Qué hace                                                                                                 |
# | ----------------------- | -------------------------------------------------------------------------------------------------------- |
# | `COPY`                  | Copia archivos dentro del contenedor.                                                                    |
# | `--from=build`          | Le dice a Docker que los archivos se copian **desde otra etapa del mismo Dockerfile**, llamada `build`.  |
# | `/app/dist/${APP_NAME}` | Ruta dentro de esa etapa donde Angular genera los archivos compilados (`index.html`, JS, CSS, etc.).     |
# | `/usr/share/nginx/html` | Ruta dentro de la imagen de **Nginx** donde deben colocarse los archivos para ser servidos públicamente. |

# ✅ index.html → es el entry point principal de Angular.
# ✅ Los demás archivos (.js, .css, etc.) también van ahí.
# ✅ COPY ... /usr/share/nginx/html → pone todo el build en el servidor Nginx.
# ✅ Y por eso tu app se renderiza desde esa ruta.

COPY --from=build /app/dist/${APP_NAME} /usr/share/nginx/html

# Construye una imagen Docker usando el Dockerfile actual, deteniéndose en la etapa llamada dev, y asígnale el nombre myapp:dev.
# | Parte          | Qué hace                                                                                                                                                     |
# | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
# | `docker build` | Inicia el proceso de construcción de una imagen Docker.                                                                                                      |
# | `-t myapp:dev` | Le da un **nombre (`myapp`) y una etiqueta (`dev`)** a la imagen resultante. <br>➡️ Ejemplo: luego podrás ejecutar `docker run myapp:dev`.                   |
# | `--target dev` | Indica que solo se construya hasta la **etapa `dev`** del Dockerfile (multi-stage build). <br>Así no sigue hasta la de producción (`prod`, `builder`, etc.). |
# | `.`            | Contexto de build → le dice a Docker que use el **Dockerfile y archivos del directorio actual**.                                                             |
# Si no se le pone -t (tag) pone nombre aleatorio
# docker build -t <nombre>:<etiqueta> . | docker build -t myapp:dev .

# -----: docker build -t myapp:dev --target dev .


# docker run - Ejecuta contenedor Basado en una imagen existente
# --rm - eliminar el contendor cuando se detiene
# -it combina 2 flags (-i) mantiene la seccion activa - (-t) asigna terminal (TTY) mostrando logs y escribir comandos
# -p 4200:4200 -  Expone el 4200 del contenedor en tu maquina
# -v (valumen) "$PWD":/app - Monta tu carpeta actual ($PWD) dentro del contenedor en /app. Esto permite sincronizar tu código local con el contenedor (hot-reload en Angular).
# myapp:dev - el nombre de la imagen que construiste
# “Ejecuta un contenedor a partir de la imagen myapp:dev que ya tengo en mi máquina.”

# -----: docker run --rm -it -p 4200:4200 -v "$PWD":/app myapp:dev


# | Parte                                | Qué hace                                                                                                                                                                      |
# | ------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
# | `docker build`                       | Inicia el proceso de construcción de una imagen Docker.                                                                                                                       |
# | `-t myapp:prod`                      | Asigna nombre y etiqueta a la imagen resultante:<br>→ `myapp` = nombre<br>→ `prod` = etiqueta (tag).                                                                          |
# | `--target prod`                      | Le indica a Docker que **solo construya hasta la etapa `prod`** del Dockerfile. <br>Esto es útil en un *multi-stage build* donde tienes `base`, `dev`, `build`, y `prod`.     |
# | `--build-arg APP_NAME=<tu-proyecto>` | Pasa el argumento de build (`ARG`) definido en el Dockerfile. <br>En este caso, `APP_NAME` se reemplaza por el nombre de tu proyecto Angular (por ejemplo: `my-angular-app`). |
# | `.`                                  | Usa el **Dockerfile y archivos** del directorio actual como contexto de build.                                                                                                |

#  docker build -t myapp:prod --target prod --build-arg APP_NAME=<tu-proyecto> .


#  Parte        | Significado                                                                                               |
# | ------------ | --------------------------------------------------------------------------------------------------------- |
# | `--rm`       | Elimina el contenedor **al salir o detenerlo** (`Ctrl+C`). 🧹                                             |
# | `-p 8080:80` | Mapea el puerto **8080 del host** al **80 del contenedor**. <br>👉 Accedes desde `http://localhost:8080`. |
# | `myapp:prod` | Imagen base (la app de producción).                                                                       |

# docker ps -Lista de contenedores
# docker stop <id_o_nombre>

# Para correrlo de manera local
#   docker build -t myapp:dev --targe dev