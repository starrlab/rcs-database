"""
move_and_archive.py

This script automates the archival of RC+S session data from synced directories to a permanent, un-synced archive location.
It automatically generates source paths for RCS01-RCS20 subjects in both StarrLab and SummitContinuousBilateralStreaming data source directories.
Each subject gets both left (L) and right (R) hemisphere variants. For each subject, the script finds session folders (both "Session*" and "session*"), applies a time-based filter to avoid moving recent data, and uses rsync to move (or simulate moving) session data to a structured archive.
The script supports a dry-run mode for safe simulation and logs all operations to both a file and the console.

Key features:
- Automatically generates source paths for RCS01-RCS20 subjects
- Moves only sessions older than a configurable threshold (default: 8 hours).
- Uses rsync with checksum verification for data integrity.
- Supports multiple source paths per subject (e.g., both StarrLab and SummitContinuousBilateralStreaming).
- Automatically detects data type from each source path and routes to appropriate destination structure.
- A subject can have data in both data sources - these are complementary, not mutually exclusive.
- Handles both uppercase ("Session*") and lowercase ("session*") session folder naming conventions.
- Avoids overwriting existing data in the destination.
- Provides detailed logging and error handling.
- Designed for safe, repeatable, and auditable archival operations.

Usage:
    python move_and_archive.py [--dry-run]

Configuration:
    Automatically generates source paths for RCS01-RCS20 subjects in both data source directories.
    Each subject gets both left (L) and right (R) hemisphere variants.
    Only processes subjects that have existing data directories.
    Handles session folders named with both "Session" and "session" prefixes.
"""
import logging
import subprocess
import argparse  # Added for command-line argument handling
import re
import shutil
from datetime import datetime, timedelta
from pathlib import Path

# --- Configuration ---
# Base path for data sources (remote server paths)
DATA_BASE = Path('/media/dropbox_hdd/Starr Lab Dropbox')

# NOTE: Throughout this script, 'subject_id' refers to a deidentified patient ID, which may include a hemisphere suffix (e.g., 'RCS02L', 'GaitRCS01L').
# The script automatically constructs source paths for RCS01-RCS20 subjects in both data source directories.
# A subject can have data in both StarrLab and SummitContinuousBilateralStreaming directories - these are complementary data sources.

# Base path for the permanent, un-synced archive
UNSYNCED_BASE_PATH = Path('/media/dropbox_hdd/Starr Lab Dropbox/RC+S Patient Un-Synced Data')

# Log file for this script's operations
LOG_FILE = Path('logs/move_and_archive.log')

# Safety feature: only move sessions older than this duration
MOVE_AGE_THRESHOLD = timedelta(hours=8)

# --- Main Logic ---
def setup_logging():
    """
    Sets up logging to both a file and the console for the script.

    This function ensures that all log messages are written to a log file as well as output to the console, using a consistent format.
    The log file directory is created if it does not exist.
    """
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    log_format = '[%(levelname)s] %(asctime)s — %(message)s'
    file_handler = logging.FileHandler(LOG_FILE)
    file_handler.setFormatter(logging.Formatter(log_format))
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(logging.Formatter(log_format))
    logging.basicConfig(
        level=logging.INFO,
        handlers=[file_handler, console_handler]
    )

def get_session_age(session_path: Path) -> timedelta:
    """
    Determines the age of a session directory based on its name.

    Args:
        session_path (Path): Path object pointing to the session directory. The directory name is expected to be in the format 'Session<timestamp_ms>' or 'session<timestamp_ms>'.

    Returns:
        timedelta: The time difference between now and the session's timestamp. If the timestamp cannot be parsed, returns timedelta.max.
    """
    try:
        # Use regex to match both "Session" and "session" followed by timestamp
        # Pattern: ^[Ss]ession(\d+)$ - matches Session/session + any number of digits
        match = re.match(r'^[Ss]ession(\d+)$', session_path.name)
        if not match:
            raise ValueError(f"Session folder name does not match expected pattern: {session_path.name}")
            
        timestamp_ms_str = match.group(1)
        timestamp_s = int(timestamp_ms_str) / 1000
        session_time = datetime.fromtimestamp(timestamp_s)
        return datetime.now() - session_time
    except (ValueError, IndexError):
        logging.warning(f"Could not parse timestamp from session folder: {session_path.name}")
        return timedelta.max # Treat as old enough to move if unparseable

def generate_subject_paths():
    """
    Generates a dictionary mapping subject IDs to their source paths.
    
    Creates paths for RCS01-RCS20 subjects in both StarrLab and SummitContinuousBilateralStreaming directories.
    Each subject gets both left (L) and right (R) hemisphere variants.
    A subject can have data in both data sources, so both are included if they exist.
    
    Special case: RCS02 uses patient directory 'RC02LTE' instead of 'RCS02'.
    
    Returns:
        dict: Dictionary mapping subject_id to list of source paths.
    """
    subjects_to_process = {}
    
    # Generate RCS01 through RCS20
    for i in range(1, 21):
        if i == 2:
            # Special case: RCS02 uses 'RC02LTE' as patient directory
            patient_id = "RC02LTE"
        else:
            patient_id = f"RCS{i:02d}"  # RCS01, RCS03, ..., RCS20
        
        # Create both left and right hemisphere variants
        for hemisphere in ['L', 'R']:
            subject_id = f"RCS{i:02d}{hemisphere}"  # Always use RCS02L, RCS02R for subject ID
            
            # Check if both data source directories exist for this subject
            # Structure: /media/dropbox_hdd/Starr Lab Dropbox/RCS01/SummitData/SummitContinuousBilateralStreaming/RCS01L
            # Special case for RCS02: /media/dropbox_hdd/Starr Lab Dropbox/RC02LTE/SummitData/SummitContinuousBilateralStreaming/RCS02L
            starr_lab_path = DATA_BASE / patient_id / 'SummitData' / 'StarrLab' / subject_id
            summit_path = DATA_BASE / patient_id / 'SummitData' / 'SummitContinuousBilateralStreaming' / subject_id
            
            source_paths = []
            if starr_lab_path.exists():
                source_paths.append(str(starr_lab_path))
            if summit_path.exists():
                source_paths.append(str(summit_path))
            
            # Only add subjects that have at least one data source
            if source_paths:
                subjects_to_process[subject_id] = source_paths
    
    return subjects_to_process

def get_destination_path(subject_id: str, session_name: str, src_base_path: Path) -> Path:
    """
    Constructs the destination path for a given session based on subject ID and session name.

    Args:
        subject_id (str): The deidentified subject identifier (may include hemisphere, e.g., 'RCS02L', 'GaitRCS01L').
        session_name (str): The name of the session directory (e.g., 'Session1608052648432').
        src_base_path (Path): The source base path to determine the data type.

    Returns:
        Path: The full destination path where the session should be archived.
    """
    # e.g., subject_id 'RCS02L' -> patient_folder 'RCS02 Un-Synced Data'
    # e.g., subject_id 'GaitRCS01L' -> patient_folder 'GaitRCS01 Un-Synced Data'
    
    patient_id = subject_id.rstrip('LR')
    patient_folder_name = f"{patient_id} Un-Synced Data"

    # Determine the data type based on the source path
    # Check which data source directory the path belongs to (these are complementary data sources)
    src_path_str = str(src_base_path)
    if 'StarrLab' in src_path_str:
        data_type = 'StarrLab'
    elif 'SummitContinuousBilateralStreaming' in src_path_str:
        data_type = 'SummitContinuousBilateralStreaming'
    else:
        # Default fallback - log warning and use SummitContinuousBilateralStreaming
        logging.warning(f"Could not determine data type from source path: {src_base_path}. Defaulting to SummitContinuousBilateralStreaming.")
        data_type = 'SummitContinuousBilateralStreaming'

    # Destination directory structure:
    # <Un-Synced Base>/<Patient Un-Synced Data>/SummitData/<data_type>/<subject_id>/<session_name>
    # Examples:
    # /media/dropbox_hdd/Starr Lab Dropbox/RC+S Patient Un-Synced Data/RCS02 Un-Synced Data/SummitData/SummitContinuousBilateralStreaming/RCS02L/Session1608052648432
    # /media/dropbox_hdd/Starr Lab Dropbox/RC+S Patient Un-Synced Data/RCS02 Un-Synced Data/SummitData/StarrLab/RCS02L/Session1608052648432
    return UNSYNCED_BASE_PATH / patient_folder_name / 'SummitData' / data_type / subject_id / session_name

def move_session_data(src_session: Path, dest_session: Path, dry_run: bool):
    """
    Moves session data from the source to the destination using rsync, or simulates the move if dry_run is True.

    Args:
        src_session (Path): Path to the source session directory.
        dest_session (Path): Path to the destination session directory.
        dry_run (bool): If True, performs a dry run (simulation) without moving or deleting files. If False, performs the actual move.

    Returns:
        None
    """
    
    if not src_session.is_dir():
        logging.error(f"Source is not a directory: {src_session}")
        return

    # Base command for both modes. -a (archive), -v (verbose), -c (checksum)
    base_rsync_command = ['rsync', '-avc'] 
    
    if dry_run:
        print()  # Add a true blank line before simulating a move
        logging.info(f"[DRY RUN] Simulating move for '{src_session.name}' to '{dest_session}'")
        # Add the dry-run flag '-n'. DO NOT add --remove-source-files.
        rsync_command = base_rsync_command + ['--dry-run', str(src_session) + '/', str(dest_session)]
    else:
        print()  # Add a true blank line before an actual move
        logging.info(f"Moving '{src_session.name}' to '{dest_session}' with checksum verification.")
        dest_session.parent.mkdir(parents=True, exist_ok=True)
        # For a live run, add the flag to remove source files after successful copy.
        # Command: rsync -avc --remove-source-files /path/to/source/ /path/to/dest
        # The '-c' or '--checksum' flag is added for true data integrity verification.
        rsync_command = base_rsync_command + ['--remove-source-files', str(src_session) + '/', str(dest_session)]

    try:
        # Execute the constructed command (either live or dry run)
        result = subprocess.run(rsync_command, check=True, capture_output=True, text=True)
        
        # The verbose output of rsync is useful in both modes.
        log_prefix = "[DRY RUN] " if dry_run else ""
        # Indent multi-line rsync output for clarity
        rsync_output = result.stdout.strip().replace('\n', '\n    ')
        logging.info(f"{log_prefix}rsync summary for {src_session.name}:\n    {rsync_output}")
        print()  # This produces a true blank line in the console only
        
        # --- Post-rsync actions (only for live run) ---
        if not dry_run:
            # After a successful checksum-verified move, the source directory should be empty.
            try:
                logging.info(f"Removing source directory and any remaining empty subdirectories: {src_session}")
                shutil.rmtree(src_session)
            except OSError as e:
                logging.warning(f"Could not remove source directory {src_session}. Error: {e}")

    except subprocess.CalledProcessError as e:
        # This block will be entered if rsync returns a non-zero exit code (an error).
        logging.error(f"rsync command failed for {src_session.name}.")
        logging.error(f"  Command: {' '.join(str(arg) for arg in e.args)}")
        logging.error(f"  Return Code: {e.returncode}")
        logging.error(f"  STDOUT: {e.stdout.strip()}")
        logging.error(f"  STDERR: {e.stderr.strip()}")
    except Exception as e:
        logging.error(f"An unexpected error occurred during operation for {src_session.name}: {e}")

def main():
    """
    Main function to run the archival process.

    This function parses command-line arguments, sets up logging, generates subject paths automatically, and processes each subject and session directory for archival. It applies a time-based filter and uses rsync to move or simulate moving session data.

    Returns:
        None
    """
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(
        description="Archives RC+S session data from synced to un-synced directories."
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help="Perform a detailed dry run simulation without moving or deleting any files."
    )
    args = parser.parse_args()

    setup_logging()
    
    # Add blank line before script start
    logging.info("")
    if args.dry_run:
        logging.info("--- Starting Move and Archive script in DRY RUN mode ---")
    else:
        logging.info("--- Starting Move and Archive script in LIVE mode ---")
    logging.info("")

    # Generate subject paths automatically instead of loading from JSON
    subjects_to_process = generate_subject_paths()
    if not subjects_to_process:
        logging.warning("No subject directories found. Exiting.")
        return
    
    logging.info(f"Found {len(subjects_to_process)} subjects to process")
        
    for subject_id, source_paths in subjects_to_process.items():
        # Handle both single string and list of strings for source paths
        if isinstance(source_paths, str):
            source_paths = [source_paths]
        elif not isinstance(source_paths, list):
            logging.warning(f"Invalid source path format for {subject_id}: {source_paths}. Skipping.")
            continue
            
        logging.info(f"Processing subject: {subject_id} with {len(source_paths)} source path(s)")
        
        for src_base_path_str in source_paths:
            src_base_path = Path(src_base_path_str)
            logging.info(f"  Processing source path: {src_base_path}")

            if not src_base_path.exists():
                logging.warning(f"  Source path for {subject_id} does not exist. Skipping.")
                continue

            # Find all session directories using regex pattern
            # Use a single glob with pattern that matches both Session* and session*
            session_dirs = []
            for item in src_base_path.iterdir():
                if item.is_dir() and re.match(r'^[Ss]ession\d+', item.name):
                    session_dirs.append(item)
            
            for session_path in session_dirs:
                if not session_path.is_dir():
                    continue

                # 1. Apply the time-based filter
                age = get_session_age(session_path)
                if age < MOVE_AGE_THRESHOLD:
                    logging.info(f"  Skipping recent session '{session_path.name}' (age: {age}).")
                    continue

                # 2. Determine the destination
                dest_session_path = get_destination_path(subject_id, session_path.name, src_base_path)
                if dest_session_path.exists() and not args.dry_run:
                    logging.warning(f"  Destination '{dest_session_path}' already exists. Skipping to avoid data loss.")
                    continue

                # 3. Move the data, passing the dry_run flag
                move_session_data(session_path, dest_session_path, dry_run=args.dry_run)

    # Add blank line before script finish
    logging.info("")
    logging.info("--- Move and Archive script finished. ---")
    logging.info("")


if __name__ == "__main__":
    main()