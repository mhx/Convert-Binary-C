typedef enum {
  SUNDAY, MONDAY, TUESDAY, WEDNESDAY,
  THURSDAY, FRIDAY, SATURDAY
} Weekday;

typedef enum {
  JANUARY, FEBRUARY, MARCH, APRIL, MAY, JUNE, JULY,
  AUGUST, SEPTEMBER, OCTOBER, NOVEMBER, DECEMBER
} Month;

typedef struct {
  int     year;
  Month   month;
  int     day;
  Weekday weekday;
} Date;
