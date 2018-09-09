const path = require("path");
const webpack = require("webpack");
const CleanWebpackPlugin = require("clean-webpack-plugin");

let pathsToClean = ["public/assets/dist"];

module.exports = {
  entry: {
    "assets/dist/index": "./public/assets/coffee/index.coffee",
    "assets/dist/preparation": "./public/assets/coffee/preparation.coffee",
    "assets/dist/online": "./public/assets/coffee/online.coffee",
    "assets/dist/repair": "./public/assets/coffee/repair.coffee",
    "assets/dist/select": "./public/assets/coffee/select.coffee",
    "assets/dist/reservation": "./public/assets/coffee/reservation.coffee",
    "dist/dashboard-room": "./_typescripts/dashboard/room.tsx"
  },
  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "public")
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: ["style-loader", "css-loader"]
      },
      {
        test: /\.(eot|svg|ttf|woff|woff2|otf)$/,
        use: {
          loader: "file-loader",
          options: {
            outputPath: "/assets/dist/",
            publicPath: "/assets/dist/"
          }
        }
      },
      {
        test: /\.html$/,
        loader: "handlebars-loader"
      },
      {
        test: /\.coffee$/,
        use: [
          {
            loader: "coffee-loader",
            options: {
              transpile: {
                presets: ["env"]
              }
            }
          }
        ]
      },
      {
        test: /\.less$/,
        use: ["style-loader", "css-loader", "less-loader"]
      },
      {
        test: /\.js$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: ["env"]
          }
        }
      },
      {
        test: /\.tsx?$/,
        use: "ts-loader",
        exclude: /node_modules/
      },
      {
        test: /\.scss$/,
        use: [
          "style-loader", // creates style nodes from JS strings
          "css-loader", // translates CSS into CommonJS
          "sass-loader" // compiles Sass to CSS
        ]
      }
    ]
  },
  resolve: {
    // Add '.ts' and '.tsx' as resolvable extensions.
    extensions: [".ts", ".tsx", ".js", ".json"]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: "jquery",
      jQuery: "jquery",
      _: "underscore"
    }),
    new CleanWebpackPlugin(pathsToClean)
  ]
};
