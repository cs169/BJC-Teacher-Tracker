import path from "path"
import resolve from "@rollup/plugin-node-resolve"
import commonjs from "@rollup/plugin-commonjs"
import postcss from "rollup-plugin-postcss"
import copy from "rollup-plugin-copy"

const buildDir = "app/assets/builds"
const buildDirAbsolute = path.resolve(buildDir)
const nodeModulesPath = path.resolve("node_modules")

export default {
  input: {
    application: "app/javascript/application.js",
    bjc: "app/javascript/bjc.js",
    schools: "app/javascript/schools.js",
  },
  output: {
    dir: buildDir,
    format: "esm",
    sourcemap: true,
    entryFileNames: "[name].js",
    chunkFileNames: "[name]-[hash].js",
    assetFileNames: "[name]-[hash][extname]"
  },
  plugins: [
    resolve({
      browser: true,
    }),
    commonjs(),
    postcss({
      extract: path.join(buildDirAbsolute, "application.css"),
      sourceMap: true,
      modules: false,
      use: [
        [
          "sass",
          {
            includePaths: [nodeModulesPath],
          },
        ],
      ],
    }),
    copy({
      targets: [
        { src: "app/javascript/images/**/*", dest: `${buildDir}/images` },
        { src: "app/javascript/img/**/*", dest: `${buildDir}/img` },
        { src: "app/javascript/fonts/**/*", dest: `${buildDir}/fonts` },
        { src: "node_modules/@fortawesome/fontawesome-free/webfonts/*", dest: `${buildDir}/fonts` },
      ],
      hook: "writeBundle",
    }),
  ],
  watch: {
    clearScreen: false,
  },
}
