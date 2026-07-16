enum SharedConstants {
    enum GroupUserDefaults {
        #if STAGING
            public static let groupContainerId = "group.com.jamesgooch.podcastria"
        #else
            public static let groupContainerId = "group.au.com.shiftyjelly.pocketcasts"
        #endif
        public static let upNextItems = "upNextItems"
        public static let upNextItemsCount = "upNextItemsCount"
        public static let siriSearchItems = "siriSearchItems"
        public static let topFilterName = "topFilterTitle"
        public static let topFilterItems = "topFilterItems"
        public static let isPlaying = "isPlaying"
        public static let appIcon = "appIcon"
    }

    enum PlaybackEffects {
        public static let maximumPlaybackSpeed = 3.0
        public static let minimumPlaybackSpeed = 0.5
    }
}

enum ProductFeaturePolicy {
    #if STAGING
        static let usesPocketCastsSubscriptions = false
        static let hasLocalPremiumAccess = true
    #else
        static let usesPocketCastsSubscriptions = true
        static let hasLocalPremiumAccess = false
    #endif
}
