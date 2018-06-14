const path = require("path");
const webpack = require("webpack");

module.exports = {
  mode: "production",
  devtool: "inline-source-map",
  entry: {
    index: [
      "./public/assets/dist/js/common.js",
      "./public/assets/dist/js/index.js",
      "./public/assets/dist/js/default-css.js"
    ],
    preparation: [
      "./public/assets/dist/js/common.js",
      "./public/assets/dist/js/preparation.js",
      "./public/assets/dist/js/default-css.js"
    ],
    online: [
      "./public/assets/dist/js/common.js",
      "./public/assets/dist/js/online.js",
      "./public/assets/dist/js/dashboard-css.js"
    ]
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
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: "jquery",
      jQuery: "jquery",
      _: "underscore"
    })
  ]
};
