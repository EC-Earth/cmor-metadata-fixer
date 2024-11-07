#!/usr/bin/env python

import argparse
import os
import json
import netCDF4
import logging
import uuid
import datetime
import multiprocessing
from pathlib import Path
from functools import partial

script_version         = 'v1.0'
script_name            = 'cmorMDfixer'
latest_applied_version = 'latest_applied_cmorMDfixer_version'

log = logging.getLogger(os.path.basename(__file__))

skipped_attributes = ["source", "comment"]

log_overview_modified_attributes = ''

def fix_file(path, write=True, keepid=False, forceid=False, metadata=None, add_attributes=False):
    global log_overview_modified_attributes
    ds = netCDF4.Dataset(path, "r+" if write else "r")
    modified = forceid

    if metadata is not None:
        for key, val in metadata.items():
            attname, attval = str(key), val
            if attname.startswith('#') or attname in skipped_attributes:
                continue
            if (not hasattr(ds, attname) and add_attributes) or \
                    (hasattr(ds, attname) and str(getattr(ds, attname)) != str(attval)):
                log.info("Setting metadata field %s to %s in %s" % (attname, attval, ds.filepath()))
                log_overview_modified_attributes=log_overview_modified_attributes+'Set ' + attname + ' to ' + str(attval) + '. '
                if write:
                    setattr(ds, attname, attval)
                modified = True
    if modified and not keepid:
        tr_id = '/'.join(["hdl:21.14100", (str(uuid.uuid4()))])
        log.info("Setting tracking_id to %s for %s" % (tr_id, ds.filepath()))
        if write:
            setattr(ds, "tracking_id", tr_id)
    if modified:
        history = getattr(ds, "history", "")
        creation_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
        log.info("Appending message about modification to the history attribute.")
        log.info('Set attribute %s to %s' % (latest_applied_version, script_version))
        if write:
            if log_overview_modified_attributes == '':
             log_overview_modified_attributes = 'No attribute has been modified.'
            setattr(ds, latest_applied_version, script_version)
            setattr(ds, "history", history + '%s: Metadata update by applying the %s %s: %s \n' % (creation_date, script_name, script_version, log_overview_modified_attributes))
    ds.close()
    return modified


def process_file(path, npp=1, flog=None, write=True, keepid=False, forceid=False, metadata=None, add_attributes=False):
    try:
        modified = fix_file(path, write, keepid, forceid, metadata, add_attributes)
        if modified:
            if npp != 1:
                flog.put(path)
            elif hasattr(flog, "write"):
                flog.write(path + '\n')
    except IOError as io_err:
        log.error("An IO error for file %s occurred: %s" % (path, io_err.message))
    except AttributeError as att_err:
        log.error("An attribute error for file %s occurred: %s" % (path, att_err.message))


def listener(q, fname):
    with open(fname, 'w') as flog:
        while 1:
            elem = q.get()
            if elem == "kill":
                break
            flog.write(str(elem) + '\n')
            flog.flush()


def main(args=None):
    if args is None:
        pass
    ofilename = "list-of-modified-files-1.txt"
    formatter = lambda prog: argparse.HelpFormatter(prog,max_help_position=30)
    parser = argparse.ArgumentParser(description="Fix meta data i.e. CMOR attributes in cmorized files", formatter_class=formatter)
    parser.add_argument("meta", metavar="FILE.json", type=str,
                        help="The attribute values in this metadata file will be used to overwrite the corresponding attributes in the cmorised data. "
                             "This will apply to ALL netcdf files recursively found in your data directory. New attributes in this "
                             "file will be skipped unless the --addatts option is used.")
    parser.add_argument("datadir", metavar="DIR", type=str, help="Directory containing cmorized files")
    parser.add_argument("--depth", "-d", type=int, help="Directory recursion depth (default: infinite)")
    parser.add_argument("--verbose", "-v", action="store_true", default=False,
                        help="Run verbosely (default: off)")
    parser.add_argument("--dry", "-s", action="store_true", default=False,
                        help="Dry run, no writing (default: no)")
    parser.add_argument("--keepid", "-k", action="store_true", default=False,
                        help="Keep tracking id (default: no)")
    parser.add_argument("--forceid", "-f", action="store_true", default=False,
                        help="Force new tracking id (default: no)")
    parser.add_argument("--olist", metavar="LOGDIR", type=str, default=False,
                        help="List all modified files in " + ofilename + " in LOGDIR")
    parser.add_argument("--addattrs", "-a", action="store_true", default=False,
                        help="Add new attributes from metadata file")
    parser.add_argument("--npp", type=int, default=1, help="Number of sub-processes to launch (default 1)")

    args = parser.parse_args()

    # Obligatory arguments:
    metajson = args.meta
    if not os.path.isfile(metajson):
        log.error("The metadata json file argument %s is not a valid file: Skipping the metadata modification." % metajson)
        return
    with open(metajson) as jsonfile:
        metadata = json.load(jsonfile)
    odir = args.datadir
    if not os.path.isdir(odir):
        log.error("Data directory argument %s is not a valid directory: Skipping the metadata modification." % odir)
        return

    # Optional arguments:
    # depth:
    depth = getattr(args, "depth", None)
    # verbose:
    logformat = "%(asctime)s %(levelname)s:%(name)s: %(message)s"
    logdateformat = "%Y-%m-%d %H:%M:%S"
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG, format=logformat, datefmt=logdateformat)
    else:
        logging.basicConfig(level=logging.WARNING, format=logformat, datefmt=logdateformat)
    # keepid & forceid:
    if args.keepid and args.forceid:
        log.error("Options keepid and forceid are mutually exclusive, please choose either the one or the other.")
        return
    # npp:
    npp=args.npp
    if npp < 1 or npp > 128:
        log.error("Invalid number of subprocesses chosen, please pick a number in the range: 1 - 128")
        return
    # olist (LOGDIR/list-of-modified-files):
    logdir = getattr(args, "olist", None)
    if logdir:
       if os.path.isdir(logdir):
          if not os.access(logdir, os.W_OK):
             log.error("Abort because no write permission for the LOGDIR %s" % logdir)
             return
       elif os.path.isfile(logdir):
           log.error("Abort because %s is not a directory." % logdir)
           return
       else:
          Path(logdir).mkdir(parents=True, exist_ok=True)
       ofilename = os.path.join(logdir, ofilename)
       if os.path.isfile(ofilename):
        i = 1
        while os.path.isfile(ofilename):
            i += 1
            newfilename = os.path.join(logdir, "list-of-modified-files-" + str(i) + ".txt")
            log.warning("Output file name %s already exists, trying %s" % (ofilename, newfilename))
            ofilename = newfilename

    # Sequential or parallel call:
    if npp == 1:
        ofile = open(ofilename, 'w') if logdir else None
        worker = partial(process_file, npp=1, flog=ofile, write=not args.dry, keepid=args.keepid, forceid=args.forceid,
                         metadata=metadata, add_attributes=args.addattrs)
        for root, dirs, files in os.walk(odir, followlinks=False):
            if depth is None or root[len(odir):].count(os.sep) < int(depth):
                for filepath in files:
                    fullpath = os.path.join(root, filepath)
                    if not os.path.islink(fullpath) and filepath.endswith(".nc"):
                        worker(fullpath)
    else:
        considered_files = []
        for root, dirs, files in os.walk(odir, followlinks=False):
            if depth is None or root[len(odir):].count(os.sep) < int(depth):
                for filepath in files:
                    fullpath = os.path.join(root, filepath)
                    if not os.path.islink(fullpath) and filepath.endswith(".nc"):
                        considered_files.append(fullpath)
        manager = multiprocessing.Manager()
        fq = manager.Queue()
        pool = multiprocessing.Pool(processes=npp)
        watcher = pool.apply_async(func=listener, args=(fq, ofilename))
        jobs = []
        for f in considered_files:
            job = pool.apply_async(func=process_file, args=(f, npp, fq, not args.dry, args.keepid, args.forceid, metadata, args.addattrs))
            jobs.append(job)
        for job in jobs:
            job.get()
        # now we are done, kill the listener
        fq.put("kill")
        pool.close()
        pool.join()


if __name__ == "__main__":
    main()
