#!/usr/bin/env node
/**
 * Regenerates `.agents/skills/` so Codex can discover this repository's skills.
 *
 * Codex scans `.agents/skills/` upward from the working directory. Nothing else
 * populates it, so the generated tree is committed: a fresh checkout has working
 * skills without anyone having run this first.
 *
 * Sources, in priority order — the first directory found under a given skill name
 * wins, and later sources are not merged into it:
 *
 *   1. <repo>/.codex/skills/<name>/       Codex-native edition of a project skill
 *   2. <repo>/.claude/skills/<name>/      Claude Code edition of a project skill
 *
 * With `--include-global`, two more sources are appended:
 *
 *   3. ~/.claude/plugins/cache/ ** /skills/<name>/   installed plugin skills
 *   4. ~/.claude/skills/<name>/           the user's own global skills
 *
 * Those two are opt-in because the result is committed. Codex has no plugin system,
 * so vendoring is the only way it can reach a plugin skill — but vendoring writes one
 * machine's installed set into the repository, where it then ages without anyone
 * noticing. Turn it on when a Codex run genuinely needs those skills, record the
 * decision, and re-run deliberately rather than on a schedule.
 *
 * When anything is vendored, `.agents/skills/.vendored` records it as a `sha256sum`-format
 * manifest: one `<hex>  <path>` line per file, paths relative to `.agents/skills/`.
 * Nothing here reads that file — it exists so `scripts/skills.test.sh` can tell a
 * deliberately vendored skill from a directory somebody added by hand, which are otherwise
 * the same thing: a skill in the generated tree with no source in this repository.
 *
 * It records contents rather than names because a name alone only proves the directory is
 * still there. The vendored copy is committed and lives in the repository like any other
 * file, so a hand edit inside it is exactly as likely as one anywhere else, and a check
 * that accepted the directory by name would be blind to it.
 *
 * The manifest is written inside the directory this script clears and rebuilds, so it
 * cannot outlive the tree it describes.
 *
 * Two kinds of skill are skipped rather than copied:
 *   - anything named in IGNORE below, when a Codex-native replacement supersedes it;
 *   - anything whose SKILL.md frontmatter carries `superseded-by:`, which is how this
 *     repository records that a skill was replaced but not yet deleted.
 *
 * The target directory is cleared and rebuilt on every run, so this is idempotent —
 * and destructive. Do not run it to propagate a single edit: it regenerates the whole
 * tree against the local checkout, which in a checkout behind the default branch
 * deletes committed skills that exist upstream. Copy the one directory by hand.
 */

import { createHash } from 'node:crypto';
import { promises as fs } from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const targetDir = path.join(repoRoot, '.agents', 'skills');
const home = os.homedir();

/**
 * Project skills deliberately not copied, each with the reason. Keep the reason:
 * an entry whose justification is forgotten gets deleted by the next person who
 * cannot see why it is here.
 *
 * @type {Record<string, string>}
 */
const IGNORE = {
  // 'task-pipeline': 'the .codex edition is the active Codex version',
};

const SKIP_DIRS = /^(node_modules|\.git|dist|build|coverage)$/;

/**
 * Every directory under `dir` that directly contains a SKILL.md.
 *
 * @param {string} dir
 * @returns {Promise<string[]>}
 */
async function findSkillDirs(dir) {
  const found = [];

  async function walk(current) {
    let entries;
    try {
      entries = await fs.readdir(current, { withFileTypes: true });
    } catch {
      return; // Missing or unreadable source — not an error, just nothing to copy.
    }
    for (const entry of entries) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) {
        if (SKIP_DIRS.test(entry.name)) continue;
        await walk(full);
      } else if (entry.isFile() && entry.name === 'SKILL.md') {
        found.push(current);
      }
    }
  }

  await walk(dir);
  return found;
}

/**
 * True when the skill's frontmatter marks it as replaced by a successor.
 *
 * Reads only the leading frontmatter block: `superseded-by` appearing further down
 * the document is prose about some other skill, not a marker on this one.
 *
 * @param {string} skillDir
 * @returns {Promise<boolean>}
 */
async function isSuperseded(skillDir) {
  let text;
  try {
    text = await fs.readFile(path.join(skillDir, 'SKILL.md'), 'utf8');
  } catch {
    return false;
  }
  const match = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text);
  if (!match) return false;
  return /^superseded-by:\s*\S/m.test(match[1]);
}

/**
 * Every file under `dir`, at any depth, as absolute paths.
 *
 * @param {string} dir
 * @returns {Promise<string[]>}
 */
async function filesUnder(dir) {
  const out = [];
  for (const entry of await fs.readdir(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...(await filesUnder(full)));
    else if (entry.isFile()) out.push(full);
  }
  return out;
}

async function main() {
  const includeGlobal = process.argv.includes('--include-global');

  const sources = [
    { label: '.codex', dir: path.join(repoRoot, '.codex', 'skills') },
    { label: '.claude', dir: path.join(repoRoot, '.claude', 'skills') },
  ];

  if (includeGlobal) {
    sources.push(
      { label: 'plugins', dir: path.join(home, '.claude', 'plugins', 'cache') },
      { label: 'user', dir: path.join(home, '.claude', 'skills') },
    );
  }

  /** @type {Map<string, {from: string, label: string}>} */
  const chosen = new Map();
  const skipped = [];

  for (const source of sources) {
    for (const skillDir of await findSkillDirs(source.dir)) {
      const name = path.basename(skillDir);

      if (chosen.has(name)) continue; // A higher-priority source already claimed it.

      if (IGNORE[name]) {
        skipped.push(`${name} — ignored: ${IGNORE[name]}`);
        continue;
      }
      if (await isSuperseded(skillDir)) {
        skipped.push(`${name} — superseded-by marker in frontmatter`);
        continue;
      }

      chosen.set(name, { from: skillDir, label: source.label });
    }
  }

  await fs.rm(targetDir, { recursive: true, force: true });
  await fs.mkdir(targetDir, { recursive: true });

  for (const [name, { from }] of [...chosen].sort(([a], [b]) => a.localeCompare(b))) {
    await fs.cp(from, path.join(targetDir, name), { recursive: true });
  }

  // Record what came from outside the repository, so the drift check can tell a vendored skill
  // from a hand-added directory. Written only when there is something to record: an empty manifest
  // and an absent one mean the same thing, and two ways of saying it is one way too many.
  const vendored = [...chosen]
    .filter(([, { label }]) => label === 'plugins' || label === 'user')
    .map(([name]) => name)
    .sort((a, b) => a.localeCompare(b));

  if (vendored.length > 0) {
    const lines = [];
    for (const name of vendored) {
      for (const file of (await filesUnder(path.join(targetDir, name))).sort()) {
        const digest = createHash('sha256').update(await fs.readFile(file)).digest('hex');
        lines.push(`${digest}  ${path.relative(targetDir, file)}`);
      }
    }
    await fs.writeFile(path.join(targetDir, '.vendored'), `${lines.join('\n')}\n`);
  }

  const width = Math.max(0, ...[...chosen.keys()].map((n) => n.length));
  for (const [name, { label }] of [...chosen].sort(([a], [b]) => a.localeCompare(b))) {
    console.log(`  ${name.padEnd(width)}  ← ${label}`);
  }
  for (const line of skipped.sort()) {
    console.log(`  skipped: ${line}`);
  }
  console.log(`\n${chosen.size} skill(s) written to ${path.relative(repoRoot, targetDir)}`);
  if (!includeGlobal) {
    console.log('  project sources only — pass --include-global to vendor plugin and user skills');
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
