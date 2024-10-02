/************
Auteur: Antoine Oberson
Contact : antoine@oberson.com
date:02.10.2024

************/
#include <Unistep2.h>

#include <DCMotor.h>

#include <Servo.h>


//AccelStepper stepper_rota(8, 9, 10, 11);  // déclare les pin pour le moteur de rotation
const unsigned long stepsPerRevolution = 4096;
const unsigned long rotationContinue = 2 ^ 15 - 1;             //valeur max d'un int car la librairie est crée comme ça = 8 tours
Unistep2 stepper_rota(8, 9, 10, 11, stepsPerRevolution, 900);  // déclare les pin pour le moteur de rotation

#define relay_pin 7
#define servo_pin 5

DCMotor pompe = DCMotor(2, 4, 3);  //défini la pompe d'injection de liquide

Servo AiguilleServo;  //déclare l'objet du controle du servo de l'aiguille

void SerialClear();

unsigned long Time;
unsigned long temps_Toggle = 200;  //on va toggle la pompe de liquide toutes les x secondes

int mode = -1;
int Rotation_Tf = -1;
int Rotation_Temps = 0;
unsigned long Spray_Temps = 0;
int Prime_Motor_Mode = -1;
int Prime_Motor_enable = 0;

String trame;

int pompe_tournee = 0;

void setup() {
  Serial.begin(115200);
  Serial.setTimeout(250);
  pinMode(relay_pin, OUTPUT);

  AiguilleServo.attach(servo_pin);  //initialise le servo
  AiguilleServo.write(180);         // 180 est la position où l'aiguille est fermée

  delay(1000);  //attendre 1 sec pour pas recevoir le serial de l'esp
}

void loop() {
  stepper_rota.run();
  if (Serial.available() > 0) {  //on attends une commande de la part de l'esp

    trame = Serial.readString();
    //on cherche la première virgule
    int commaIndex = trame.indexOf(',');
    //  cherche la seconde virgule
    int secondCommaIndex = trame.indexOf(',', commaIndex + 1);
    // cherche la troisième virgule
    int thirdCommaIndex = trame.indexOf(',', secondCommaIndex + 1);

    String firstValue = trame.substring(0, commaIndex);
    String secondValue = trame.substring(commaIndex + 1, secondCommaIndex);
    String thirdValue = trame.substring(secondCommaIndex + 1, thirdCommaIndex);
    String fourthValue = trame.substring(thirdCommaIndex + 1);  // To the end of the string

    mode = firstValue.toInt();

    switch (mode) {
      case 0:  //mode == 0 donc on est en fabrication de spray
        {
          Rotation_Tf = secondValue.toInt();
          Rotation_Temps = thirdValue.toInt();
          Spray_Temps = fourthValue.toInt();
          break;
        }

      case 1:  //mode == 1 donc on est en mode fonction
        {
          Prime_Motor_Mode = secondValue.toInt();
          Prime_Motor_enable = thirdValue.toInt();
          break;
        }
    }
    SerialClear();
  }

  //interprétation des valeurs lues

  switch (mode) {
    case 0:  //mode spray
    {
      switch (Rotation_Tf) {
        case 0:  //rotation off
          {

            digitalWrite(relay_pin, HIGH);
            pompe.on(200);
            unsigned long time_ref = millis();
            AiguilleServo.write(0);
            while ((millis() - time_ref) < (Spray_Temps * 1000)) {  // on spray pour le temps donné

              if ((millis() - time_ref) >= (0.9 * Spray_Temps * 1000) || (millis() - time_ref) >= Spray_Temps * 1000 - 1000) {  // on arrête la pompe peristaltique et on ferme l'aiguille pour éviter les gouttes avant la fin
                pompe.off();
                AiguilleServo.write(180);  //test
              }
            }
            AiguilleServo.write(180);
            pompe.off();
            digitalWrite(relay_pin, LOW);

            break;
          }

        case 1:  //rotation ON
          {

            if (Rotation_Temps == Spray_Temps) {
              //stepper_rota.runSpeed();
              unsigned long time_ref = millis();


              time_ref = millis();

              digitalWrite(relay_pin, HIGH);
              AiguilleServo.write(0);               //ouvre l'aiguille à 100%
              stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
              pompe.on(250);
              stepper_rota.run();
              int pompe_state = 1;  // sert à connaitre l'etat de la pompe pour le toggle on/off

              unsigned long time_ref_toggle = millis();
              while ((millis() - time_ref) < (Spray_Temps * 1000)) {  // on spray pour le temps donné

                stepper_rota.run();


                if (stepper_rota.stepsToGo() <= 10) {   //si on arrive au bout du mouvement, on remet des pas à effectuer
                  stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
                  stepper_rota.run();
                }

                if ((millis() - time_ref_toggle) >= temps_Toggle) {  //toggle l'état de la pompe,après une attente de temps_toggle cette méthode ne bloque pas le stepper
                  switch (pompe_state) {
                    case 0:  //si pompe off on l'allume
                      pompe.on(250);
                      pompe_state = 1;
                      break;

                    case 1:  // si pompe on on l'étein
                      pompe.off();
                      pompe_state = 0;
                      break;
                  }

                  time_ref_toggle = millis();
                }

                if ((millis() - time_ref) >= (0.9 * Spray_Temps * 1000) || (millis() - time_ref) >= Spray_Temps * 1000 - 1000) {  // on arrête la pompe peristaltique et on ferme l'aiguille pour éviter les gouttes avant la fin
                  pompe.off();
                  AiguilleServo.write(180);  //test
                }
              }

              pompe.off();
              AiguilleServo.write(180);
              digitalWrite(relay_pin, LOW);
              time_ref = millis();
              stepper_rota.stop();
            }

            else if (Rotation_Temps > Spray_Temps) {  //pourquoi cela se passerait ? C'est juste du proofing d'erreur
              //stepper_rota.runSpeed();
              digitalWrite(relay_pin, HIGH);
              AiguilleServo.write(0);               //ouvre l'aiguille à fond
              stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
              pompe.on(250);

              int pompe_state = 1;
              unsigned long time_ref = millis();
              unsigned long time_ref_toggle = millis();
              while ((millis() - time_ref) < (Rotation_Temps * 1000)) {  // on spray pour le temps donné
                //stepper_rota.runSpeed();
                stepper_rota.run();
                //stepper_rota.step(5);

                if (stepper_rota.stepsToGo() <= 10) {   //si on arrive au bout du mouvement, on remet des pas à effectuer
                  stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
                }

                if ((millis() - time_ref_toggle) >= temps_Toggle) {  //toggle l'état de la pompe,après une attente de temps_toggle cette méthode ne bloque pas le stepper
                  switch (pompe_state) {
                    case 0:  //si pompe off on l'allume
                      pompe.on(250);
                      pompe_state = 1;
                      break;

                    case 1:  // si pompe on on l'étein
                      pompe.off();
                      pompe_state = 0;
                      break;
                  }

                  time_ref_toggle = millis();
                }

                if ((millis() - time_ref) >= (Spray_Temps * 1000)) {  //coupe l'air comprimé au temps donné
                  AiguilleServo.write(180);
                  digitalWrite(relay_pin, LOW);
                  pompe.off();
                }

                if ((millis() - time_ref) >= (0.9 * Rotation_Temps * 1000) || ((millis() - time_ref) >= Rotation_Temps * 1000 - 1000)) {  // on arrête la pompe peristaltique et on ferme l'aiguille pour éviter les gouttes avant la fin
                  AiguilleServo.write(180);
                  digitalWrite(relay_pin, LOW);
                  pompe.off();
                }
              }
              stepper_rota.stop();
            }

            else if (Rotation_Temps < Spray_Temps) {  //pourquoi cela se passerait ? C'est juste du proofing d'erreur
              //stepper_rota.runSpeed();
              digitalWrite(relay_pin, HIGH);
              AiguilleServo.write(0);
              stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
              pompe.on(200);
              int pompe_state = 1;
              unsigned long time_ref = millis();
              unsigned long time_ref_toggle = millis();
              while ((millis() - time_ref) < (Spray_Temps * 1000)) {  // on spray pour le temps donné
                //stepper_rota.runSpeed();
                stepper_rota.run();
                //stepper_rota.step(5);

                if (stepper_rota.stepsToGo() <= 10) {   //si on arrive au bout du mouvement, on remet des pas à effectuer
                  stepper_rota.move(rotationContinue);  //on mets un grands nombre de tours pour faire tourner le moteur indéfiniment
                }

                if ((millis() - time_ref_toggle) >= temps_Toggle) {  //toggle l'état de la pompe,après une attente de temps_toggle cette méthode ne bloque pas le stepper
                  switch (pompe_state) {
                    case 0:  //si pompe off on l'allume
                      pompe.on(250);
                      pompe_state = 1;
                      break;

                    case 1:  // si pompe on on l'étein
                      pompe.off();
                      pompe_state = 0;
                      break;
                  }

                  time_ref_toggle = millis();
                }

                if ((millis() - time_ref) >= (Rotation_Temps * 1000)) {  //arrête la rotation au temps donné
                  stepper_rota.stop();
                }

                if ((millis() - time_ref) >= (0.9 * Spray_Temps * 1000) || ((millis() - time_ref) >= Spray_Temps * 1000 - 1000)) {  // on arrête la pompe peristaltique et on ferme l'aiguille pour éviter les gouttes avant la fin
                  AiguilleServo.write(180);
                  digitalWrite(relay_pin, LOW);
                  pompe.off();
                }
              }
              AiguilleServo.write(180);
              digitalWrite(relay_pin, LOW);
              pompe.off();
            }
            break;
          }
      }

      Serial.print("fini");
      Serial.flush();
      mode = -1;
      break;
    }
    case 1:  //mode fonction
      {
        switch (Prime_Motor_Mode) {
          case 0:  //mode amorçage
            if (Prime_Motor_enable == 1) {
              if (pompe_tournee == 0) {
                AiguilleServo.write(0);
                pompe_tournee = 1;
              }

              pompe.on(200);
            } else if (Prime_Motor_enable == 0) {
              AiguilleServo.write(180);
              pompe_tournee = 0;
              pompe.off();
            }
            mode = -1;
            break;

          case 1:  //mode désamorçage
            if (Prime_Motor_enable == 1) {
              if (pompe_tournee == 0) {
                AiguilleServo.write(0);
                pompe_tournee = 1;
              }
              pompe.on(-200);
            } else if (Prime_Motor_enable == 0) {
              AiguilleServo.write(180);
              pompe_tournee = 0;
              pompe.off();
            }
            mode = -1;
            break;
        }
      }
  }
}

void SerialClear() {
  while (Serial.available() > 0) {
    char t = Serial.read();
  }
}