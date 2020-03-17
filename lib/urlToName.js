const path = require('path')

// String -> String

// @url examples:
// - https://registry.yarnpkg.com/acorn-es7-plugin/-/acorn-es7-plugin-1.1.7.tgz
// - https://registry.npmjs.org/acorn-es7-plugin/-/acorn-es7-plugin-1.1.7.tgz
// - git+https://github.com/srghma/node-shell-quote.git
// - git+https://1234user:1234pass@git.graphile.com/git/users/1234user/postgraphile-supporter.git

function urlToName(url) {
  if (url.startsWith('git+')) {
    return path.basename(url)
  }

  return url
    .replace('https://registry.yarnpkg.com/', '') // prevents having long directory names
    .replace(/[@/:-]/g, '_') // replace @ and : and - characters with underscore
}

const yarnpkgRegex = /https:\/\/registry.yarnpkg.com\/(?:(@.+?)\/.+?|(.+?))\/-\/(.+?)#.+/
const gitRegex = /(?:git\+|https:\/\/github.com).+/

function resolvedToName(resolved) {
  const yarnpkgMatches = resolved.match(yarnpkgRegex);
  if (yarnpkgMatches) {
    const m = yarnpkgMatches;
    const scoped = !m[2]
    if (scoped) {
      return `${m[1]}-${m[3]}`
    } else {
      return m[3]
    }
  }

  if (resolved.startsWith('git+') || resolved.startsWith('https://github.com')) {
    return path.basename(resolved).replace('#', '-')
  }

  throw new Error(`Don't know how to handle ${resolved}`)
}

module.exports = { urlToName, resolvedToName }
