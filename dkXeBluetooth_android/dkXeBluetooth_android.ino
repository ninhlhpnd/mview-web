#include <Servo.h>
#include "DHT.h"
#define in1 9
#define in2 10
#define in3 11
#define in4 12
#define ena 5
#define enb 6
#define TRIG_PIN 7
#define ECHO_PIN 8
#define servoTrai_pin 3
#define servoPhai_pin 4
#define nhietdo_pin 2
#define led A5
#define quangtro_pin A6
#define buzzer 13

#define DHTTYPE DHT11
DHT dht(nhietdo_pin, DHTTYPE);

unsigned long timeKc = 0;
Servo servotrai;
Servo servophai;
int gocservotrai = 90;
int gocservophai = 90;
float nhietdo = 0, doam = 0;
int quangtro = 0;
bool stringComplete = false;
String inputString = "", command = "", dulieu = "";
unsigned long timeSend = 0;
void setup() {
  Serial.begin(9600);
  pinMode(in1, OUTPUT);
  pinMode(in2, OUTPUT);
  pinMode(in3, OUTPUT);
  pinMode(in4, OUTPUT);
  pinMode(ena, OUTPUT);
  pinMode(enb, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(nhietdo_pin, INPUT);
  pinMode(led, OUTPUT);
  pinMode(quangtro_pin, INPUT);
  pinMode(buzzer, OUTPUT);
  dht.begin();

  inputString.reserve(50); // Dự phòng bộ nhớ để tránh phân mảnh
  
  analogWrite(ena, 130);
  analogWrite(enb, 130);
  servotrai.attach(servoTrai_pin);
  servophai.attach(servoPhai_pin);
  servotrai.write(gocservotrai);
  servophai.write(gocservophai);
}

// Hàm di chuyển servo từ từ để tránh sụt áp đột ngột
void moveServo(Servo &s, int &currentGoc, int targetGoc) {
  targetGoc = constrain(targetGoc, 60, 120); // Giới hạn góc từ 60 đến 120 độ
  while (currentGoc != targetGoc) {
    if (currentGoc < targetGoc) currentGoc++;
    else currentGoc--;
    s.write(currentGoc);
    delay(5); // Delay nhỏ để giảm dòng khởi động đột ngột
  }
}

void loop() {
  while (Serial.available()) {
    char c = (char)Serial.read();
    inputString += c;
    // Serial.print(c);
    if (c == '\n') stringComplete = true;
  }                   
  if (stringComplete) {
    // Serial.print("Received: ");
    // Serial.print(inputString); // In ra để xem lệnh nhận được là gì
    int vitri = inputString.indexOf('=');  
    command = inputString.substring(0, vitri);
    // Serial.print(inputString);
    if (command.equals("ledon")) {
      digitalWrite(led, 1);
    } else if (command.equals("ledoff")) {
      digitalWrite(led, 0);
    } else if (command.equals("coion")) {
      digitalWrite(buzzer, 1);
    } else if (command.equals("coioff")) {
      digitalWrite(buzzer, 0);
    } else if (command.equals("tien")) {
      dulieu = inputString.substring(vitri + 1, inputString.length() - 1);
      int tocdoxe = dulieu.toInt();
      diTien(tocdoxe);
    } else if (command.equals("lui")) {
      dulieu = inputString.substring(vitri + 1, inputString.length() - 1);
      int tocdoxe = dulieu.toInt();
      diLui(tocdoxe);
    } else if (command.equals("trai")) {
      dulieu = inputString.substring(vitri + 1, inputString.length() - 1);
      int tocdoxe = dulieu.toInt();
      reTrai(tocdoxe);
    } else if (command.equals("phai")) {
      dulieu = inputString.substring(vitri + 1, inputString.length() - 1);
      int tocdoxe = dulieu.toInt();
      rePhai(tocdoxe);
    } else if (command.equals("dung")) {
      dung();
    } else if (command.equals("kep")) {
      kep();
    } else if (command.equals("nha")) {
      nha();
    } else if (command.equals("nang")) {
      nang();
    } else if (command.equals("ha")) {
      ha();
    }
    stringComplete = false;
    inputString = "";
    dulieu = "";
    command="";
  }
  if (millis() - timeSend > 1000) {
    docNhietdoDoam();
    docQuangtro();
    float khoangcach = GetDistance();
    // Gửi dữ liệu định dạng: Nhiệt độ|Độ ẩm|Độ sáng|Khoảng cách
    String dulieuSend = String(nhietdo, 1) + "|" + String(doam, 1) + "|" + String(quangtro) + "|" + String(khoangcach, 1);
    Serial.println(dulieuSend); // Dùng println để app dễ nhận diện kết thúc chuỗi
    timeSend = millis();
  }
}
float GetDistance() {
  long duration;
  float distanceCm;
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  duration = pulseIn(ECHO_PIN, HIGH);

  // convert to distance
  distanceCm = duration / 29.1 / 2;

  return distanceCm;
}
void diTien(int tocdo) {
  digitalWrite(in1, 0);
  digitalWrite(in2, 1);
  digitalWrite(in3, 0);
  digitalWrite(in4, 1);
  analogWrite(ena, tocdo);
  analogWrite(enb, tocdo);
}
void diLui(int tocdo) {
  digitalWrite(in1, 1);
  digitalWrite(in2, 0);
  digitalWrite(in3, 1);
  digitalWrite(in4, 0);
  analogWrite(ena, tocdo);
  analogWrite(enb, tocdo);
}
void reTrai(int tocdo) {
  digitalWrite(in1, 1);
  digitalWrite(in2, 0);
  digitalWrite(in3, 0);
  digitalWrite(in4, 1);
  analogWrite(ena, tocdo);
  analogWrite(enb, tocdo);
}
void rePhai(int tocdo) {
  digitalWrite(in1, 0);
  digitalWrite(in2, 1);
  digitalWrite(in3, 1);
  digitalWrite(in4, 0);
  analogWrite(ena, tocdo);
  analogWrite(enb, tocdo);
}
void dung() {
  digitalWrite(in1, 0);
  digitalWrite(in2, 0);
  digitalWrite(in3, 0);
  digitalWrite(in4, 0);
}
void kep() {
  moveServo(servotrai, gocservotrai, gocservotrai - 5);
}
void nha() {
  moveServo(servotrai, gocservotrai, gocservotrai + 5);
}
void nang() {
  moveServo(servophai, gocservophai, gocservophai - 5);
}
void ha() {
  moveServo(servophai, gocservophai, gocservophai + 5);
}
void docQuangtro() {
  quangtro = analogRead(quangtro_pin);
}
void docNhietdoDoam() {
  nhietdo = dht.readTemperature();
  doam = dht.readHumidity();
}
void serialEvent() {
}