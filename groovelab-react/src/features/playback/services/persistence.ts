/**
 * Persistence Service — IndexedDB storage for playback sessions
 *
 * Uses the `idb` library (already in project deps) to persist:
 * - Repertoire/setlist data
 * - Mix snapshots
 * - Session state
 * - Audio file references (not raw buffers — those are loaded on demand)
 */
import { openDB, type IDBPDatabase } from 'idb'
import type { PlaybackRepertoire, MixSnapshot, PlaybackSession } from '../types'

const DB_NAME = 'groovelab-playback'
const DB_VERSION = 1

interface PlaybackDB {
  repertoires: {
    key: string
    value: PlaybackRepertoire
  }
  sessions: {
    key: string
    value: PlaybackSession
  }
  snapshots: {
    key: string
    value: MixSnapshot
  }
  audioFiles: {
    key: string
    value: { id: string; trackId: string; songId: string; blob: Blob; name: string }
  }
}

let dbInstance: IDBPDatabase<PlaybackDB> | null = null

async function getDb(): Promise<IDBPDatabase<PlaybackDB>> {
  if (dbInstance) return dbInstance
  dbInstance = await openDB<PlaybackDB>(DB_NAME, DB_VERSION, {
    upgrade(db) {
      if (!db.objectStoreNames.contains('repertoires')) {
        db.createObjectStore('repertoires', { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains('sessions')) {
        db.createObjectStore('sessions', { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains('snapshots')) {
        db.createObjectStore('snapshots', { keyPath: 'id' })
      }
      if (!db.objectStoreNames.contains('audioFiles')) {
        db.createObjectStore('audioFiles', { keyPath: 'id' })
      }
    },
  })
  return dbInstance
}

/* ── Repertoire CRUD ── */

export async function saveRepertoire(rep: PlaybackRepertoire): Promise<void> {
  const db = await getDb()
  await db.put('repertoires', { ...rep, updatedAt: Date.now() })
}

export async function getRepertoire(id: string): Promise<PlaybackRepertoire | undefined> {
  const db = await getDb()
  return db.get('repertoires', id)
}

export async function getAllRepertoires(): Promise<PlaybackRepertoire[]> {
  const db = await getDb()
  return db.getAll('repertoires')
}

export async function deleteRepertoire(id: string): Promise<void> {
  const db = await getDb()
  await db.delete('repertoires', id)
}

/* ── Session CRUD ── */

export async function saveSession(session: PlaybackSession): Promise<void> {
  const db = await getDb()
  await db.put('sessions', { ...session, updatedAt: Date.now() })
}

export async function getSession(id: string): Promise<PlaybackSession | undefined> {
  const db = await getDb()
  return db.get('sessions', id)
}

export async function getLatestSession(): Promise<PlaybackSession | undefined> {
  const db = await getDb()
  const all = await db.getAll('sessions')
  if (all.length === 0) return undefined
  return all.sort((a, b) => b.updatedAt - a.updatedAt)[0]
}

/* ── Mix Snapshots ── */

export async function saveMixSnapshot(snap: MixSnapshot): Promise<void> {
  const db = await getDb()
  await db.put('snapshots', snap)
}

export async function getAllMixSnapshots(): Promise<MixSnapshot[]> {
  const db = await getDb()
  return db.getAll('snapshots')
}

/* ── Audio Files ── */

export async function saveAudioFile(
  trackId: string,
  songId: string,
  blob: Blob,
  name: string,
): Promise<string> {
  const db = await getDb()
  const id = `${songId}-${trackId}-${Date.now()}`
  await db.put('audioFiles', { id, trackId, songId, blob, name })
  return id
}

export async function getAudioFile(id: string) {
  const db = await getDb()
  return db.get('audioFiles', id)
}

export async function getAudioFilesForSong(songId: string) {
  const db = await getDb()
  const all = await db.getAll('audioFiles')
  return all.filter(f => f.songId === songId)
}
