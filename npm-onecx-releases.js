#!/usr/bin/env node
/**
 * Lists all packages published under the `@onecx` npm scope and, for each of them,
 * the most recent release of every major version (or only the given ones) including
 * the dist-tags pointing at that release and how long ago it was published.
 *
 * Usage:
 *   node tools/npm-onecx-releases.js [--scope onecx] [--majors 5,6,7,8] [--json]
 */

// Run
// node npm-onecx-releases.js


const REGISTRY = 'https://registry.npmjs.org'
const SEARCH_PAGE_SIZE = 250

function parseArgs(argv) {
  // `majors: null` means "every major the package has published"
  const args = { scope: 'onecx', majors: null, json: false }
  for (let i = 0; i < argv.length; i++) {
    switch (argv[i]) {
      case '--scope':
        args.scope = argv[++i].replace(/^@/, '')
        break
      case '--majors':
        args.majors = argv[++i]
          .split(',')
          .map((m) => Number(m.trim()))
          .filter((m) => Number.isInteger(m))
        break
      case '--json':
        args.json = true
        break
      default:
        throw new Error(`Unknown argument: ${argv[i]}`)
    }
  }
  return args
}

async function fetchJson(url) {
  const response = await fetch(url, { headers: { accept: 'application/json' } })
  if (!response.ok) {
    throw new Error(`Request to ${url} failed with status ${response.status}`)
  }
  return response.json()
}

async function fetchScopePackageNames(scope) {
  const names = new Set()
  let from = 0
  let total = Infinity
  while (from < total) {
    const url = `${REGISTRY}/-/v1/search?text=${encodeURIComponent(`@${scope}`)}&size=${SEARCH_PAGE_SIZE}&from=${from}`
    const page = await fetchJson(url)
    total = page.total ?? 0
    if (!page.objects?.length) break
    for (const entry of page.objects) {
      if (entry.package?.name?.startsWith(`@${scope}/`)) {
        names.add(entry.package.name)
      }
    }
    from += page.objects.length
  }
  return [...names].sort()
}

/** Compares two semver strings, returns a positive number when `a` is newer than `b`. */
function compareVersions(a, b) {
  const split = (version) => {
    const [core, prerelease] = version.split('-')
    return { parts: core.split('.').map(Number), prerelease }
  }
  const left = split(a)
  const right = split(b)
  for (let i = 0; i < 3; i++) {
    if ((left.parts[i] ?? 0) !== (right.parts[i] ?? 0)) {
      return (left.parts[i] ?? 0) - (right.parts[i] ?? 0)
    }
  }
  if (left.prerelease === right.prerelease) return 0
  if (!left.prerelease) return 1
  if (!right.prerelease) return -1
  return left.prerelease < right.prerelease ? -1 : 1
}

function majorOf(version) {
  return Number(version.split('.')[0].replace(/[^0-9]/g, ''))
}

function formatDuration(fromIso, now) {
  const ms = now - new Date(fromIso).getTime()
  if (!Number.isFinite(ms)) return 'unknown'
  const minutes = Math.floor(ms / 60000)
  const hours = Math.floor(minutes / 60)
  const days = Math.floor(hours / 24)
  const months = Math.floor(days / 30.44)
  const years = Math.floor(days / 365.25)
  if (years >= 1) return `${years}y ${Math.floor((days - years * 365.25) / 30.44)}mo ago`
  if (months >= 1) return `${months}mo ${days - Math.floor(months * 30.44)}d ago`
  if (days >= 1) return `${days}d ${hours - days * 24}h ago`
  if (hours >= 1) return `${hours}h ago`
  return `${minutes}m ago`
}

async function collectPackageInfo(name, requestedMajors, now) {
  const doc = await fetchJson(`${REGISTRY}/${name.replace('/', '%2f')}`)
  const times = doc.time ?? {}
  const distTags = doc['dist-tags'] ?? {}
  const versions = Object.keys(doc.versions ?? {})
  const majors = requestedMajors ?? [...new Set(versions.map(majorOf))].filter(Number.isInteger).sort((a, b) => a - b)

  const releases = majors.map((major) => {
    const candidates = versions.filter((version) => majorOf(version) === major)
    if (!candidates.length) return { major, version: null }
    const version = candidates.sort(compareVersions).pop()
    const publishedAt = times[version] ?? null
    return {
      major,
      version,
      publishedAt,
      age: publishedAt ? formatDuration(publishedAt, now) : 'unknown',
      tags: Object.entries(distTags)
        .filter(([, tagged]) => tagged === version)
        .map(([tag]) => tag)
        .sort(),
    }
  })

  return { name, distTags, releases }
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length)
  let index = 0
  const runners = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (index < items.length) {
      const current = index++
      results[current] = await worker(items[current])
    }
  })
  await Promise.all(runners)
  return results
}

function printReport(packages, majors) {
  for (const pkg of packages) {
    console.log(`\n${pkg.name}`)
    if (!pkg.releases.length) {
      console.log('  no releases')
    }
    for (const release of pkg.releases) {
      if (!release.version) {
        console.log(`  v${release.major}.x  -  no release`)
        continue
      }
      const tags = release.tags.length ? release.tags.join(', ') : '-'
      console.log(
        `  v${release.major}.x  ${release.version.padEnd(24)} ${String(release.publishedAt).padEnd(26)} ${release.age.padEnd(14)} tags: ${tags}`
      )
    }
  }
  console.log(`\n${packages.length} package(s), majors checked: ${majors ? majors.join(', ') : 'all'}`)
}

async function main() {
  const args = parseArgs(process.argv.slice(2))
  const now = Date.now()
  const names = await fetchScopePackageNames(args.scope)
  if (!names.length) {
    console.error(`No packages found for scope @${args.scope}`)
    process.exitCode = 1
    return
  }
  const packages = await mapWithConcurrency(names, 8, (name) => collectPackageInfo(name, args.majors, now))

  if (args.json) {
    console.log(JSON.stringify(packages, null, 2))
  } else {
    printReport(packages, args.majors)
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exitCode = 1
})
