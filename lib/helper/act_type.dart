enum ActType {
  walking,
  bicycle,
  motorcycle,
  car,
  bus,
  train,
  ferry,
  ropeway,
  airplane,
  helicopter,
  airship,
  balloon,
  taxi,
}

extension ActTypeExtension on ActType {
  String assetsPath() {
    switch (this) {
      case ActType.walking:
        return "assets/act_icons/01_walking.png";
      case ActType.bicycle:
        return "assets/act_icons/02_bicycle.png";
      case ActType.motorcycle:
        return "assets/act_icons/03_motorcycle.png";
      case ActType.car:
        return "assets/act_icons/04_car.png";
      case ActType.bus:
        return "assets/act_icons/05_bus.png";
      case ActType.train:
        return "assets/act_icons/06_train.png";
      case ActType.ferry:
        return "assets/act_icons/07_ferry.png";
      case ActType.ropeway:
        return "assets/act_icons/08_ropeway.png";
      case ActType.airplane:
        return "assets/act_icons/09_airplane.png";
      case ActType.helicopter:
        return "assets/act_icons/10_helicopter.png";
      case ActType.airship:
        return "assets/act_icons/11_airship.png";
      case ActType.balloon:
        return "assets/act_icons/12_balloon.png";
      case ActType.taxi:
        return "assets/act_icons/13_taxi.png";
    }
  }
}
