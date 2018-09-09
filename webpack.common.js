const path = require("path");
const webpack = require("webpack");
const CleanWebpackPlugin = require("clean-webpack-plugin");

let pathsToClean = ["public/assets/dist"];

module.exports = {
  entry: {
    index: "./public/assets/coffee/index.coffee",
    preparation: "./public/assets/coffee/preparation.coffee",
    online: "./public/assets/coffee/online.coffee",
    repair: "./public/assets/coffee/repair.coffee",
    select: "./public/assets/coffee/select.coffee",
    reservation: "./public/assets/coffee/reservation.coffee"
  },
  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "public", "assets", "dist")
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
      }
    ]
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
