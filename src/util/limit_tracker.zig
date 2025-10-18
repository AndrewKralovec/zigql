pub const LimitTracker = struct {
    limit: usize,
    current: usize,

    pub fn init(limit: usize) LimitTracker {
        return LimitTracker{
            .limit = limit,
            .current = 0,
        };
    }

    pub fn checkAndIncrement(self: *LimitTracker) bool {
        if (self.current >= self.limit) {
            return true;
        }
        self.current += 1;
        return false;
    }
};
