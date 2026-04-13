# =============================================================================
# SQLite Database Wrapper
# =============================================================================
# PURPOSE: Gestiona el comptador de visites amb SQLite
#
# WHAT TO DO:
# - El fitxer DB es crea automàticament a data/visits.db
# - init_db() crea la taula si no existeix
# - Thread-safe per concurrent requests
# - Atomic increment using RETURNING clause
# =============================================================================

import sqlite3
from pathlib import Path
import threading
import atexit


class Database:
    """Thread-safe SQLite database wrapper for visit counter"""
    
    def __init__(self, db_path: str = "data/visits.db"):
        """
        Initialize database connection
        
        Args:
            db_path: Relative path to SQLite database file
        """
        self.db_path = Path(__file__).parent / db_path
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self.local = threading.local()
        self._connections = []
        self._lock = threading.Lock()
        
        # Register cleanup on exit
        atexit.register(self.close_all_connections)
    
    def get_connection(self) -> sqlite3.Connection:
        """
        Get thread-local database connection
        
        Returns:
            SQLite connection for current thread
        """
        if not hasattr(self.local, 'conn') or self.local.conn is None:
            conn = sqlite3.connect(
                str(self.db_path),
                check_same_thread=False,
                isolation_level='DEFERRED'
            )
            # Enable WAL mode for better concurrency
            conn.execute('PRAGMA journal_mode=WAL')
            conn.execute('PRAGMA synchronous=NORMAL')
            self.local.conn = conn
            
            # Track connection for cleanup
            with self._lock:
                self._connections.append(conn)
        
        return self.local.conn
    
    def close_all_connections(self):
        """Close all thread-local connections on shutdown"""
        with self._lock:
            for conn in self._connections:
                try:
                    conn.close()
                except Exception:
                    pass
            self._connections.clear()
    
    def init_db(self):
        """
        Initialize database schema
        
        Creates visits table if not exists and initializes counter to 0.
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Create table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS visits (
                id INTEGER PRIMARY KEY,
                count INTEGER NOT NULL DEFAULT 0,
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # Initialize counter if not exists
        cursor.execute("SELECT COUNT(*) FROM visits")
        if cursor.fetchone()[0] == 0:
            cursor.execute("INSERT INTO visits (id, count) VALUES (1, 0)")
        
        conn.commit()
    
    def get_visit_count(self) -> int:
        """
        Get current visit count
        
        Returns:
            Current visit count
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        cursor.execute("SELECT count FROM visits WHERE id = 1")
        result = cursor.fetchone()
        
        return result[0] if result else 0
    
    def increment_visits(self) -> int:
        """
        Atomically increment visit counter using RETURNING clause
        
        This is atomic - the UPDATE and SELECT happen in one statement,
        preventing race conditions where concurrent requests might read
        the same count before either write completes.
        
        Returns:
            New visit count after increment
        """
        conn = self.get_connection()
        cursor = conn.cursor()
        
        # Atomic increment with RETURNING (SQLite 3.35+)
        # Falls back to separate queries for older SQLite versions
        try:
            cursor.execute("""
                UPDATE visits 
                SET count = count + 1,
                    last_updated = CURRENT_TIMESTAMP
                WHERE id = 1
                RETURNING count
            """)
            result = cursor.fetchone()
            conn.commit()
            
            if result:
                return result[0]
            
            # Fallback if no row matched (shouldn't happen after init_db)
            return self.get_visit_count()
            
        except sqlite3.OperationalError as e:
            # RETURNING not supported (SQLite < 3.35)
            # Use transaction isolation instead
            if "RETURNING" in str(e).upper() or "syntax" in str(e).lower():
                cursor.execute("BEGIN IMMEDIATE")
                cursor.execute("""
                    UPDATE visits 
                    SET count = count + 1,
                        last_updated = CURRENT_TIMESTAMP
                    WHERE id = 1
                """)
                cursor.execute("SELECT count FROM visits WHERE id = 1")
                result = cursor.fetchone()
                conn.commit()
                return result[0] if result else 0
            else:
                raise
