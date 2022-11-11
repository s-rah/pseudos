
typedef long time_t;

struct timezone {
   int tz_minutewest;
   int tz_dsttime;
};

struct timeval {
   time_t      tv_sec;   // Number of whole seconds of elapsed time
   long int    tv_usec;  // Number of microseconds of rest of elapsed time minus tv_sec. Always less than one million
};