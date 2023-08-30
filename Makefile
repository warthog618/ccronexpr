CC = gcc
CFLAGS = -DCRON_USE_LOCAL_TIME -static
SOURCES = supertinycron.c ccronexpr.c
OBJECTS = $(SOURCES:.c=.o)
EXECUTABLE = supertinycron

all: $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS)
	$(CC) $(CFLAGS) $(OBJECTS) -o $@

clean:
	rm -f $(OBJECTS) $(EXECUTABLE)
