const path = require("path");
const webpack = require("webpack");
const CleanWebpackPlugin = require("clean-webpack-plugin");

let pathsToClean = ["public/assets/dist"];

module.exports = {
  mode: "production",
  devtool: "inline-source-map",
  entry: {
    index: "./public/assets/coffee/index.coffee",
    preparation: "./public/assets/coffee/preparation.coffee",
    online: "./public/assets/coffee/online.coffee",
    repair: "./public/assets/coffee/repair.coffee",
    room: "./public/assets/coffee/room.coffee",
    select: "./public/assets/coffee/select.coffee",
    reservation: "./public/assets/coffee/reservation.coffee"
  },
  output: {
    filename: "[name].js",
    path: path.resolve(__dirname, "public", "assets", "dist")
  },
  optimization: {
    splitChunks: {
      cacheGroups: {
        commons: {
          chunks: "initial",
          name: "commons",
          minChunks: 2
        }
      }
    }
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
        use: ["coffee-loader"]
      },
      {
        test: /\.less$/,
        use: ["style-loader", "css-loader", "less-loader"]
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
