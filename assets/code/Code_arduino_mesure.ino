/************
Auteur: Antoine Oberson
Contact : antoine@oberson.com
date:02.10.2024

************/
#include <Arduino.h>

#include <AccelStepper.h>
AccelStepper stepper_rota(AccelStepper::FULL4WIRE);  // Defaults to Accelstepper_rota::FULL4WIRE (4 pins) on 2, 3, 4, 5


int homing();  // function prototype
int gauche();
int droite();

//variables de la trame de commande
int mode = -1;
int translation = -1;
int distance_trans = -1;
int fonction = -1;
int distance_rota = -1;

int compte_pas = 0;        //compte les pas pour la fonction de rotation
int compte_pas_trans = 0;  //compte les pas pour la tranlation pour éviter déraillage

// pin pour stopper le moteur, elle est set sur ground pour le stopper
#define STOPPER_PIN 10

// Motor steps per revolution. Most steppers are 200 steps or 1.8 degrees/step
#define MOTOR_STEPS 400
#define RPM 60
// Mode de microstep
#define MICROSTEPS 2

//pin de controle du moteur
#define DIR 8
#define STEP 9
#define SLEEP 13

#include "DRV8825.h"
#define MODE0 7
#define MODE1 11
#define MODE2 12
DRV8825 stepper_trans(MOTOR_STEPS, DIR, STEP, SLEEP, MODE0, MODE1, MODE2);  //déclaration du moteur de translation

String data;




void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);

  pinMode(STOPPER_PIN, INPUT_PULLUP);  // set le home switch en pull-up
  pinMode(SLEEP, OUTPUT);              // set la pin 13 en output pour le sleep

  stepper_trans.begin(RPM, MICROSTEPS);  //initialise le moteur pas-à-pas de translation
    // if using enable/disable on ENABLE pin (active LOW) instead of SLEEP uncomment next line
    // stepper.setEnableActiveState(LOW);
  stepper_trans.enable();  // active le moteur de translation

  digitalWrite(SLEEP, 0);
  //setup du moteur de rotation
  stepper_rota.setMaxSpeed(1000);
  stepper_rota.setAcceleration(100);

  homing();  //fais un homing au démarrage
}

void loop() {
  if (Serial.available() > 0) {  //on attends une commande de la part de l'ordinateur


    // Lis et sépare le premier int
    mode = Serial.parseInt();

    switch (mode) {  // analyse la première valeur lue, ce qui détermine en suite quelles variables seront allouées
      case 0:        //mode mesure

        // Lis et supprime la virgule
        Serial.read();
        // Lis et sépare le second int
        translation = Serial.parseInt();

        Serial.read();
        // Lis et sépare le second int
        distance_trans = Serial.parseInt();

        // Lis et supprime la virgule
        Serial.read();
        // Lis et sépare le troisième int
        distance_rota = Serial.parseInt();

        Serial.flush();


        break;

      case 1:  //mode fonction

        // Lis et supprime la virgule
        Serial.read();
        // Lis et sépare le second int
        fonction = Serial.parseInt();

        // Lis et sépare le troisième int
        //on a des tmp pour vider le buffer de serial, car les deux dernières valeurs de trame ne sont pas utilisées
        Serial.read();
        int tmp1 = Serial.parseInt();
        Serial.read();
        int tmp2 = Serial.parseInt();

        Serial.flush();
        break;
    }
  }


  //On interprète la trame lue précédemment pour exécuter les commandes des moteurs
  switch (mode) {
    case 0:  //mode mesure

      switch (translation) {
        case 0:  //translation désactivée


          stepper_rota.move(distance_rota);  //on set la distance de rotation
          stepper_rota.setMaxSpeed(200);     //c'est la vitesse de pointe du mouvement de rotation
          stepper_rota.setAcceleration(50);  //accélération du mouvement du rotation
          stepper_rota.runToPosition();      //déclanche le mouvement

          if (stepper_rota.distanceToGo() == 0) {  //si la distance restante à parcourir est nulle on fini l'action
            Serial.flush();
            delay(5);
            Serial.print("Fini\n");

            //désactive le moteur
            mode = 1;
            fonction = 0;
          }

          break;

        case 1:  //translation activée



          //Serial.println("transaltion + rotation");
          //Serial.print("rotation: ");
          //Serial.println(distance_rota);

          stepper_rota.move(distance_rota);        //on set la distance de rotation
          stepper_rota.setMaxSpeed(200);           //c'est la vitesse de pointe du mouvement de rotation
          stepper_rota.setAcceleration(50);        //accélération du mouvement du rotation
          stepper_rota.runToPosition();            //déclanche le mouvement
          if (stepper_rota.distanceToGo() == 0) {  //si la distance restante à parcourir est nulle on fini l'action
            Serial.flush();
            delay(5);
          }

          compte_pas = compte_pas + distance_rota;               //on incrémente le nombre de pas de rotation pour savoir quand on a fait un tour complet
          compte_pas_trans = compte_pas_trans + distance_trans;  //on incrémente le nombre de pas de la translation pour controler si on est en bout de rail
          if (compte_pas >= 2048 && compte_pas_trans <= 400) {   //on a fait un tour et on check si on est au bout du rail
            digitalWrite(SLEEP, 1);                           //active le moteur
            stepper_trans.move(distance_trans * MICROSTEPS);  //on se déplace du nombre de pas donné par le pc
            compte_pas = 0;                                   //remise à 0 du status de tour
          }

          else if (compte_pas >= 2048 && compte_pas_trans > 400) {
            homing();
            compte_pas_trans = 0;
            compte_pas = 0;
          }
          //désactivation du moteur
          mode = 1;
          fonction = 0;
          Serial.print("Fini\n");
          break;
      }
      break;

    case 1:  //mode fonction

      //Serial.println("Mode Fonction");
      //Serial.print("Fonction : ");
      //Serial.println(fonction);
      //Serial.flush();
      switch (fonction) {
        case 0:  //désactive le moteur
          digitalWrite(SLEEP, 0);
          break;

        case 1:  // homing

          homing();
          fonction = 0;          //désactive le moteur
          compte_pas_trans = 0;  //reset le compte de pas de translation
          break;

        case 2:  //déplacement gauche

          gauche();
          break;

        case 3:  //déplacement droite

          droite();
          break;
      }

      break;
  }
  // int tmp = data[1] - '0'; // convertis le char en int en soustrayant l'index ASCII de 0
  // Serial.println(tmp);
  // if (tmp == 1){
  //   gauche();
  // }

  // if (tmp == 0){
  //   digitalWrite(SLEEP,0);
  // }
  unsigned wait_time_micros = stepper_trans.nextAction();
}

int homing() {

  unsigned long time_ref = millis() ; //prends le millis à l'entrée de la fonction
  unsigned long time_current = millis();

  bool homing_stat = false;
  int count_switch = 0;
  digitalWrite(SLEEP, 1);
  stepper_trans.startMove(-100 * MOTOR_STEPS * MICROSTEPS);
  while (homing_stat == false && (time_current - time_ref) <= 10000 ) { //si on dépasse 10 secondes sans sortir de la boucle on arrête !
    time_current = millis();

    unsigned wait_time_micros = stepper_trans.nextAction();
    switch (count_switch) {

      case 0:


        if (digitalRead(STOPPER_PIN) == HIGH) {
          count_switch = count_switch + 1;
          stepper_trans.stop();
        }
        break;

      case 1:

        while (digitalRead(STOPPER_PIN) == HIGH) {

          stepper_trans.move(1 * MICROSTEPS);
          delay(50);
        }
        count_switch = count_switch + 1;
        break;

      case 2:
        while (digitalRead(STOPPER_PIN) == LOW) {

          stepper_trans.move(-1 * MICROSTEPS);
          delay(20);
        }
        count_switch = count_switch + 1;
        digitalWrite(SLEEP, 0);

        homing_stat = true;
        compte_pas_trans = 0;  //on reset le compte de pas de la translation
        compte_pas = 0;
        break;
    }



    //unsigned wait_time_micros = stepper_trans.nextAction();
    
  }
  digitalWrite(SLEEP, 0);//on s'assure de désactiver le moteur
  return 1;
}

int gauche() {
  digitalWrite(SLEEP, 1);
  stepper_trans.move(4 * MICROSTEPS);
  delay(10);


  return 1;
}

int droite() {
  digitalWrite(SLEEP, 1);
  stepper_trans.move(-4 * MICROSTEPS);
  delay(10);
  //unsigned wait_time_micros = stepper_trans.nextAction();
  return 1;
}