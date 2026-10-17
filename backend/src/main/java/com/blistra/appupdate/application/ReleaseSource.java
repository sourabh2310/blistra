package com.blistra.appupdate.application;

import java.util.List;

/** Supplies recent releases, newest first. Throws when the source is unreachable. */
public interface ReleaseSource {
    List<ReleaseInfo> recentReleases();
}
