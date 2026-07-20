const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");

const config = getDefaultConfig(__dirname);

// The app imports the repo-level shared/ modules (draw schedule, data,
// ticket generator). Metro must watch that folder and resolve its bare
// imports against this project's node_modules.
config.watchFolders = [path.resolve(__dirname, "..", "shared")];
config.resolver.nodeModulesPaths = [path.resolve(__dirname, "node_modules")];

module.exports = config;
