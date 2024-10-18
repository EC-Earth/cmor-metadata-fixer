#!/usr/bin/env python

import argparse
import os
import json
import netCDF4
import logging
import uuid
import multiprocessing
from functools import partial

import datetime

version_cmorMDfixer = 'v1.0'

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
                log_overview_modified_attributes=log_overview_modified_attributes+'Set ' + attname + ' to ' + attval + '. '
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
        log.info("The latest applied cmorMDfixer version attribute is set to: " + str(version_cmorMDfixer))
        if write:
            if log_overview_modified_attributes == '':
             log_overview_modified_attributes = 'No attribute has been modified.'
            setattr(ds, "latest_applied_cmorMDfixer_version", version_cmorMDfixer)
            setattr(ds, "history", history + '%s: Metadata update by applying the cmorMDfixer %s: %s \n' % (creation_date, version_cmorMDfixer, log_overview_modified_attributes))
    #    if modified:
    #        creation_date = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%SZ")
    #        log.info("Setting creation_dr(ate to %s for %s" % (creation_date, ds.filepath()))
    #        if write:
    #            setattr(ds, "creation_date", creation_date)
    ds.close()
    return modified


def process_file(path, flog=None, write=True, keepid=False, forceid=False, metadata=None, add_attributes=False):
    try:
        modified = fix_file(path, write, keepid, forceid, metadata, add_attributes)
        if modified:
            if type(flog) == type(multiprocessing.Queue()):
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
    parser.add_argument("--olist", "-o", action="store_true", default=False,
                        help="Write " + ofilename + " listing all modified files")
    parser.add_argument("--addattrs", "-a", action="store_true", default=False,
                        help="Add new attributes from metadata file")
    parser.add_argument("--npp", type=int, default=1, help="Number of sub-processes to launch (default 1)")

    args = parser.parse_args()
    logformat = "%(asctime)s %(levelname)s:%(name)s: %(message)s"
    logdateformat = "%Y-%m-%d %H:%M:%S"
    if args.verbose:
        logging.basicConfig(level=logging.DEBUG, format=logformat, datefmt=logdateformat)
    else:
        logging.basicConfig(level=logging.WARNING, format=logformat, datefmt=logdateformat)
    if args.keepid and args.forceid:
        log.error("Options keepid and forceid are mutually exclusive, please choose either one.")
        return
    metajson = args.meta
    metadata = None
    if metajson is not None:
        with open(metajson) as jsonfile:
            metadata = json.load(jsonfile)
    odir = args.datadir
    if not os.path.isdir(odir):
        log.error("Data directory argument %s is not a valid directory: skipping fix" % odir)
        return
    depth = getattr(args, "depth", None)
    if args.npp < 1:
        log.error("Invalid number of subprocesses chosen, please pick a number > 0")
        return
    if args.olist and os.path.isfile(ofilename):
        i = 1
        while os.path.isfile(ofilename):
            i += 1
            newfilename = "list-of-modified-files-" + str(i) + ".txt"
            log.warning("Output file name %s already exists, trying %s" % (ofilename, newfilename))
            ofilename = newfilename
    if args.npp == 1:
        ofile = open(ofilename, 'w') if args.olist else None
        worker = partial(process_file, flog=ofile, write=not args.dry, keepid=args.keepid, forceid=args.forceid,
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
        pool = multiprocessing.Pool(processes=args.npp)
        watcher = pool.apply_async(listener, (fq, ofilename))
        jobs = []
        for f in considered_files:
            job = pool.apply_async(process_file, (f, fq, not args.dry, args.keepid, args.forceid, metadata,
                                                  args.addattrs))
            jobs.append(job)
        for job in jobs:
            job.get()
        # now we are done, kill the listener
        fq.put("kill")
        pool.close()
        pool.join()


if __name__ == "__main__":
    main()
