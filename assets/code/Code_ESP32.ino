/****
Auteur: Antoine Oberson
contact: antoine@oberson.com
date: 02.10.2024
****/


#include <Arduino.h>
#include <EEPROM.h>
#include <ESPUI.h>

#include <WiFi.h>
#include <ESPmDNS.h>

//Settings
#define SLOW_BOOT 0
#define HOSTNAME "SprayMachine"
#define FORCE_USE_HOTSPOT 0

//Function Prototypes
void WifiSetup();  //paramètre le wifi de l'esp32
void UISetup();    //création de l'interface

//Ci-ddsous les déclarations des functions de callback
void RotationONOFFCallback(Control *sender, int type);
void NumberTempsRotationCallback(Control *sender, int type);
void ButtonPrimePompeCallback(Control *sender, int type);
void ButtonDemarrerSprayCallback(Control *sender, int type);
void NumberTempsSprayCallback(Control *sender, int type);
void ButtonUnPrimePompeCallback(Control *sender, int type);

void SerialClear();

//UI handles

uint16_t SwitchRotationONOFF;
uint16_t NumberTempsRotation;
uint16_t ButtonPrimePompe;
uint16_t ButtonDemarrerSpray;
uint16_t NumberTempsSpray;
uint16_t ButtonUnPrimePompe;
uint16_t test;


//Variables UI

int Min_Temps_Rotation = 0;
int Max_Temps_Rotation = 100;

int Min_Temps_Spray = 1;
int Max_temps_Spray = 100;

String serial_monitor;

//Variables Trame
String trame;


int Rotation_TF = 1;
int Temps_rotation = 0;
int Temps_Spray = 1;

//Variables code

int Spray_demarre = 0;




void RotationONOFFCallback(Control *sender, int type) {
  switch (type) {
    case S_ACTIVE:
      Rotation_TF = 1;
      ESPUI.setEnabled(NumberTempsRotation, true);
      break;

    case S_INACTIVE:
      Rotation_TF = 0;
      Temps_rotation = 0;
      ESPUI.setEnabled(NumberTempsRotation, false);
      break;
  }
}

void NumberTempsRotationCallback(Control *sender, int type) {
  int tmp;
  switch (type) {  //si la valeur du number est changée, on change la variable du temps
    case N_VALUE:
      tmp = (sender->value).toInt();
      if (tmp >= Min_Temps_Rotation && tmp <= Max_Temps_Rotation) {  //il faut tester manuellement si les valeurs sont dans les min et max définis
        Temps_rotation = tmp;
      }

      else if (tmp < Min_Temps_Rotation) {
        ESPUI.updateNumber(NumberTempsRotation, Min_Temps_Rotation);  //si inférieur au min on set la valeur au min
        Temps_rotation = Min_Temps_Rotation;
      }

      else if (tmp > Max_Temps_Rotation) {
        ESPUI.updateNumber(NumberTempsRotation, Max_Temps_Rotation);  //si supérieur au max on set la valeur max
        Temps_rotation = Max_Temps_Rotation;
      }


      break;
  }
}

void ButtonPrimePompeCallback(Control *sender, int type) {

  switch (type) {
    case B_DOWN:
      Serial.print("1,0,1,0");//tant qu'on reste appuyé la pompe se prime 

      break;

    case B_UP:
      Serial.print("1,0,0,0"); //lorsque relaché on envoie le stop

      break;
  }
}

void ButtonUnPrimePompeCallback(Control *sender, int type) {

  switch (type) {
    case B_DOWN:
      Serial.print("1,1,1,0");//tant qu'on reste appuyé la pompe se unprime 
      break;

    case B_UP:
      Serial.print("1,1,0,0");//lorsque relaché on envoie le stop
  }
}

void ButtonDemarrerSprayCallback(Control *sender, int type) {
  switch (type) {
    case B_DOWN:
      SerialClear();
      serial_monitor = " \n";
      ESPUI.updateLabel(test, serial_monitor);

      Spray_demarre = 1;
      trame = String(0) + "," + String(Rotation_TF) + "," + String(Temps_rotation) + "," + String(Temps_Spray);
      Serial.print(trame);
      Serial.flush();
      break;

    case B_UP:
      break;
  }
}

void NumberTempsSprayCallback(Control *sender, int type) {
  int tmp;
  switch (type) {  //si la valeur du number est changée, on change la variable du temps
    case N_VALUE:
      tmp = (sender->value).toInt();
      if (tmp >= Min_Temps_Spray && tmp <= Max_temps_Spray) {  //il faut tester manuellement si les valeurs sont dans les min et max définis
        Temps_Spray = tmp;
        //Serial.println(Temps_Spray);
      }

      else if (tmp < Min_Temps_Spray) {
        ESPUI.updateNumber(NumberTempsSpray, Min_Temps_Spray);  //si inférieur au min on set la valeur au min
        Temps_Spray = Min_Temps_Spray;
      }

      else if (tmp > Max_temps_Spray) {
        ESPUI.updateNumber(NumberTempsSpray, Max_temps_Spray);  //si supérieur au max on set la valeur max
        Temps_Spray = Max_Temps_Rotation;
      }


      break;
  }
}

void setup() {
  Serial.begin(115200);
  while (!Serial)
    ;
  if (SLOW_BOOT) delay(5000);  //Delay booting to give time to connect a serial monitor
  WifiSetup();
  UISetup();
}

void loop() {
  // put your main code here, to run repeatedly:
  if (Spray_demarre == 1) {  //désactive le boutton de fabrication de spray pour éviter le spam
    ESPUI.setEnabled(ButtonDemarrerSpray, false);
    while (Serial.available() == 0) {
      ESPUI.setEnabled(ButtonDemarrerSpray, false);
    }
    serial_monitor = Serial.readString();
    ESPUI.updateLabel(test, serial_monitor);
    Spray_demarre = 0;
    ESPUI.setEnabled(ButtonDemarrerSpray, true);
  }
}


void UISetup() {  //section où on crée l'UI, pour plus de compréhension se référer à l'exemple "CompleteExemple" de la librairie ESPUI ainsi qu'au github
  ESPUI.setVerbosity(Verbosity::Quiet);

  ESPUI.addControl(ControlType::Separator, "Paramètres de fabrication d'écran", "", ControlColor::None, Control::noParent);
  SwitchRotationONOFF = ESPUI.addControl(Switcher, "Rotation de l'écran", "1", Sunflower, Control::noParent, RotationONOFFCallback);
  NumberTempsRotation = ESPUI.addControl(Number, "Temps de rotation de l'écran", "0", Sunflower, Control::noParent, NumberTempsRotationCallback);
  ESPUI.addControl(Min, "", String(Min_Temps_Rotation), None, NumberTempsRotation);
  ESPUI.addControl(Max, "", String(Max_Temps_Rotation), None, NumberTempsRotation);

  NumberTempsSpray = ESPUI.addControl(Number, "Temps de spray de l'écran", "1", Emerald, Control::noParent, NumberTempsSprayCallback);
  ESPUI.addControl(Min, "", String(Min_Temps_Spray), None, NumberTempsSpray);
  ESPUI.addControl(Max, "", String(Max_temps_Spray), None, NumberTempsSpray);
  ButtonDemarrerSpray = ESPUI.addControl(Button, "Fabriquer l'écran", "DÉMARRER", Emerald, Control::noParent, ButtonDemarrerSprayCallback);
  test = ESPUI.label("Serial monitor:", Emerald, "");

  ESPUI.addControl(ControlType::Separator, "Utilitaires", "", ControlColor::None, Control::noParent);
  ButtonPrimePompe = ESPUI.addControl(Button, "Amorcer pompe", "maintenir", Peterriver, Control::noParent, ButtonPrimePompeCallback);
  ButtonUnPrimePompe = ESPUI.addControl(Button, "Désamorcer pompe", "maintenir", Peterriver, Control::noParent, ButtonUnPrimePompeCallback);
  ESPUI.begin(HOSTNAME);
}

void WifiSetup() {

  WiFi.mode(WIFI_AP);  //règle le wifi en mode Access point

  WiFi.softAP(HOSTNAME, NULL);                                                                           //règle le nom du access point, et n'y appose aucun mot de passe
  WiFi.softAPConfig(IPAddress(192, 168, 1, 1), IPAddress(192, 168, 1, 1), IPAddress(255, 255, 255, 0));  //set les adresses IP pour accéder à l'interface
  //Serial.println(WiFi.softAPIP());
  //WiFi.begin(NULL,NULL);
  WiFi.setSleep(false);  //For the ESP32: turn off sleeping to increase UI responsivness (at the cost of power use)

  if (!MDNS.begin(HOSTNAME)) {  // Set the hostname to """HOSTNAME"".local"
    Serial.println("Error setting up MDNS responder!");
    while (1) {
      delay(1000);
    }
  }
}

void SerialClear() {
  while (Serial.available() > 0) {
    char t = Serial.read();
  }
}