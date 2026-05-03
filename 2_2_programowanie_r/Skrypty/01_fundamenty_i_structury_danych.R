# ==========================================================================
# TYPY DANYCH -------------------------------------------------------------
# ==========================================================================

# Przypisanie (konsekwentnie używamy <-)
wysokosc <- 25.4             # numeric
gatunek  <- "sosna"          # character
dbh      <- 254L             # integer
czy_martwe <- TRUE           # logical

# Sprawdzanie typu
class(dbh)						# Zwraca klasę obiektu
is.numeric(czy_martwe)       	# FALSE (logiczne to nie)
is.logical(czy_martwe)
is.character(czy_martwe)

# Pomoc (najczęściej używamy ? lub help)
?class
help(class)
args(class)
example(class)
apropos("class") 
help.search("class")

# ==========================================================================
# WEKTORY -----------------------------------------------------------------
# ==========================================================================

# Tworzenie wektora
klasy_wysokosci <- c(5,10,15,20,25)
# Wektoryzacja
klasy_wysokosci-5

# Tworzenie wektora funkcją c() (combine)
wys <- c(15, 16, 14.2, 24.5, 10.5, 11.4, 12.8, 11.4, 16)

sort(wys) #sortowanie elementów
rev(wys) #odwrócenie kolejności
unique(wys) #unikalne wartości
which(wys > 15) #zwraca indeks elementów, spełniających warunek
round(wys,digits = 0) #zaokrąglanie

# Funkcje statystyczne na wektorach
sum(wys)       # Suma wszystkich elementów
mean(wys)      # Średnia arytmetyczna
prod(wys)      # Iloczyn wszystkich elementów
length(wys)    # Liczba elementów w wektorze (rozmiar)
var(wys)       # Wariancja (miara rozproszenia danych)
sd(wys)        # Odchylenie standardowe (pierwiastek z wariancji)
median(wys)    # Mediana (wartość środkowa)
quantile(wys)  # Kwartyle (podział danych na 25%, 50%, 75%, 100%)
min(wys)       # Wartość minimalna
max(wys)       # Wartość maksymalna

# Wektoryzacja - operacje na całym zbiorze naraz
wys_proc <- (wys / max(wys)) * 100

# Indeksowanie (Uwaga: w R indeksujemy od 1!)
wys[1]              # Pierwszy element
wys[2:4]            # Zakres elementów
wys[wys > 15]       # Filtrowanie warunkowe

1:10
c(-5:-1,1:5)

# Przymuszenie typów (Coercion)
c(TRUE, 2, 5)       # Zamieni na numeric: 1, 2, 5
c(3, "jeden", 3)    # Zamieni na character

# Replikacja
rep(1, times = 3)
rep(c(1, 2), times = 3)
rep(c(1, 2), each = 3)
rep(c(1, 2), times = c(2, 3))
rep(c(1, 2), length.out = 5)

# Generowanie ciągów liczb
seq(1,10,0.5)
seq(1,10,1)
seq(10,1,-0.25)
seq(10,1,-0.25)
seq(1,10,length.out=7)

# Wartości losowe
runif(10)

set.seed(100)
runif(10)

# Rzutowanie wektorów
l <- rep(c(T,F),3)
as.character(l)
as.numeric(l)

# Wartości NA (Not Available)
v <- seq(1,10)
v[7] = NA
v

sum(v)
sum(v,na.rm = T)
is.na(v)

which(is.na(v))

# ==========================================================================
# MACIERZE -----------------------------------------------------------------
# ==========================================================================

# Tworzenie macierzy
m <- matrix(3,nrow=3,ncol=3)
m <- matrix(1:9,nrow=3,ncol=3)

dim(m)     # Zwraca wektor: liczba wierszy i kolumn
ncol(m)    # Liczba kolumn
nrow(m)    # Liczba wierszy

# Kierunek wypełniania
letters
matrix(letters[1:10],nrow=2)
matrix(letters[1:10],nrow=2,byrow = T)

# Operacje na przekątnej
diag(4)
m = matrix(letters[1:9],nrow=3)
diag(m)

# Łączenie macierzy
m1 <- matrix(1:4,2)
m2 <- matrix(0,2,2)

rbind(m1,m2)
cbind(m1,m2)

# Indeksowanie macierzy
m[2,1]
m[2,]
m[,1]

# Modyfikacja zawartości
m[2,1] = 'z'
m

# Zaawansowane operacje macierzowe
a <- matrix(c(2, 3, 4, 2, 1, 2, 1, 3, 2), nrow = 3)
b <- matrix(6:1, ncol=2)

a %*% b         # Mnożenie macierzowe
t(b)            # Transpozycja
det(a)          # Wyznacznik
solve(a)        # Macierz odwrotna

# ==========================================================================
# CZYNNIK (FACTOR) ---------------------------------------------------------
# ==========================================================================

# Definicja gatunków
gatunki_lista <- c("sosna", "dab", "swierk")
# Losowanie 25 elementów z powtórzeniami (replace = TRUE)
v_gat <- sample(gatunki_lista, size = 25, replace = TRUE)

# Konwersja wektora znakowego na czynnik (dane kategoryczne)
f <- factor(v_gat)
f

# Porównanie: summary dla tekstu podaje długość, dla czynnika zlicza wystąpienia
summary(v_gat)
summary(f)

# Zmiana etykiet kategorii (levels)
levels(f) <- c("db", "so", "sw")
f

# ==========================================================================
# LISTA -------------------------------------------------------------------
# ==========================================================================

# Tworzenie listy z elementami różnych typów
moja_lista <- list(TRUE,1:3,"tekst")
moja_lista

# Indeksowanie
moja_lista[2]									# Zwraca listę z jednym elementem
moja_lista[[2]]									# Zwraca zawartość elementu (wektor)

# Konwersja
unlist(moja_lista)								# Spłaszcza listę do wektora (rzutuje typy na character)

# Nazewnictwo i dostęp po nazwach
names(moja_lista) = c('log','num','text')
moja_lista[['log']]								# Wyciąga zawartość elementu po nazwie
moja_lista$log									# Szybki dostęp po nazwie
moja_lista[[1]]									# Wyciąga zawartość pierwszego elementu

# ==========================================================================
# RAMKA DANYCH ------------------------------------------------------------
# ==========================================================================

wys = runif(50,min=0.25)*40
gat = c('sosna','swierk')

drzewa <- data.frame(
  id = 1:length(wys),
  gat = sample(gat,length(wys),replace = TRUE),
  wys = wys,
  czy_martwe = sample(c(TRUE, FALSE),length(wys),replace = TRUE),
  stringsAsFactors = FALSE
)
drzewa

# Dostęp do danych
drzewa$gat            						# Wybór kolumny jako wektor
drzewa[1, ]             					# Pierwszy wiersz
drzewa[drzewa$czy_martwe == FALSE, "id"] 	# Które drzewa nie są marwe?

# Podgląd danych
head(drzewa)      	# Pierwsze 6 wierszy
head(drzewa,3)      # Pierwsze 3 wiersze
tail(drzewa)		# Ostatnie 6 wierszy
str(drzewa)       	# Struktura obiektu
summary(drzewa)   	# Podstawowe statystyki opisowe

# Agregacja
mean(drzewa$wys)
tapply(drzewa$wys, drzewa$gat, mean) # Średnia długość dla każdego gatunku

# Filtrowanie złożone
drzewa[drzewa$wys<15 & drzewa$czy_martwe == TRUE,]