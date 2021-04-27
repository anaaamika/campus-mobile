import 'package:campus_mobile_experimental/core/models/location.dart';
import 'package:campus_mobile_experimental/core/providers/availability.dart';
import 'package:campus_mobile_experimental/core/providers/bottom_nav.dart';
import 'package:campus_mobile_experimental/core/providers/cards.dart';
import 'package:campus_mobile_experimental/core/providers/classes.dart';
import 'package:campus_mobile_experimental/core/providers/dining.dart';
import 'package:campus_mobile_experimental/core/providers/employee_id.dart';
import 'package:campus_mobile_experimental/core/providers/events.dart';
import 'package:campus_mobile_experimental/core/providers/location.dart';
import 'package:campus_mobile_experimental/core/providers/map.dart';
import 'package:campus_mobile_experimental/core/providers/messages.dart';
import 'package:campus_mobile_experimental/core/providers/news.dart';
import 'package:campus_mobile_experimental/core/providers/notices.dart';
import 'package:campus_mobile_experimental/core/providers/notifications.dart';
import 'package:campus_mobile_experimental/core/providers/notifications_freefood.dart';
import 'package:campus_mobile_experimental/core/providers/parking.dart';
import 'package:campus_mobile_experimental/core/providers/scanner_message.dart';
import 'package:campus_mobile_experimental/core/providers/scanner.dart';
import 'package:campus_mobile_experimental/core/providers/shuttle.dart';
import 'package:campus_mobile_experimental/core/providers/student_id.dart';
import 'package:campus_mobile_experimental/core/providers/survey.dart';
import 'package:campus_mobile_experimental/core/providers/user.dart';
import 'package:campus_mobile_experimental/core/providers/wayfinding.dart';
import 'package:campus_mobile_experimental/core/providers/weather.dart';
import 'package:campus_mobile_experimental/ui/navigator/top.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'core/providers/scanner.dart';

List<SingleChildWidget> providers = [
  ...independentServices,
  ...dependentServices,
  ...uiConsumableProviders,
];

final FirebaseAnalytics analytics = FirebaseAnalytics();
final FirebaseAnalyticsObserver observer =
    FirebaseAnalyticsObserver(analytics: analytics);

List<SingleChildWidget> independentServices = [
  Provider.value(value: observer),
  ChangeNotifierProvider<BottomNavigationBarProvider>(
    create: (_) {
      print("CreateProvider: BottomNavigationBarProvider");
      return BottomNavigationBarProvider();
    },
    lazy: false,
  ),
  ChangeNotifierProvider<PushNotificationDataProvider>(
    create: (_) {
      print("CreateProvider: PushNotificationDataProvider");
      return PushNotificationDataProvider();
    },
    lazy: false,
  ),
  ChangeNotifierProvider<EventsDataProvider>(
    create: (_) {
      print("CreateProvider: EventsDataProvider");
      EventsDataProvider _eventsDataProvider = EventsDataProvider();
      _eventsDataProvider.fetchEvents();
      return _eventsDataProvider;
    },
  ),
  ChangeNotifierProvider<WeatherDataProvider>(
    create: (_) {
      print("CreateProvider: WeatherDataProvider");
      WeatherDataProvider _weatherDataProvider = WeatherDataProvider();
      _weatherDataProvider.fetchWeather();
      return _weatherDataProvider;
    },
  ),
  ChangeNotifierProvider<NewsDataProvider>(
    create: (_) {
      print("CreateProvider: NewsDataProvider");
      NewsDataProvider _newsDataProvider = NewsDataProvider();
      _newsDataProvider.fetchNews();
      return _newsDataProvider;
    },
  ),
  StreamProvider<Coordinates>(
    create: (_) {
      print("CreateProvider: Coordinates (LocationDataProvider)");
      return LocationDataProvider().locationStream;
    },
    lazy: false,
  ),
  ChangeNotifierProvider<CustomAppBar>(
    create: (_) {
      print("CreateProvider: CustomAppBar");
      return CustomAppBar();
    },
  ),
  ChangeNotifierProvider<NoticesDataProvider>(
    create: (_) {
      print("CreateProvider: NoticesDataProvider");
      NoticesDataProvider _noticesDataProvider = NoticesDataProvider();
      _noticesDataProvider.fetchNotices();
      return _noticesDataProvider;
    },
  ),
];
List<SingleChildWidget> dependentServices = [
  ChangeNotifierProxyProvider<Coordinates, DiningDataProvider>(create: (_) {
    print("CreateProvider: DiningDataProvider");
    var diningDataProvider = DiningDataProvider();
    diningDataProvider.fetchDiningLocations();
    return diningDataProvider;
  }, update: (_, coordinates, diningDataProvider) {
    print("UpdateProvider: DiningDataProvider");
    diningDataProvider.coordinates = coordinates;
    diningDataProvider.populateDistances();
    return diningDataProvider;
  }),
  ChangeNotifierProxyProvider<Coordinates, MapsDataProvider>(create: (_) {
    var mapsDataProvider = MapsDataProvider();
    return mapsDataProvider;
  }, update: (_, coordinates, mapsDataProvider) {
    print("UpdateProvider: MapsDataProvider");
    mapsDataProvider.coordinates = coordinates;
    mapsDataProvider.populateDistances();
    return mapsDataProvider;
  }),
  ChangeNotifierProxyProvider<PushNotificationDataProvider, UserDataProvider>(
      create: (_) {
        print("CreateProvider: UserDataProvider");
        var _userDataProvider = UserDataProvider();

        /// try to load any persistent saved data
        /// once loaded from memory get the user's online profile
        _userDataProvider
            .loadSavedData()
            .whenComplete(() => _userDataProvider.fetchUserProfile());
        return _userDataProvider;
      },
      lazy: false,
      update: (_, pushNotificationDataProvider, _userDataProvider) {
        print("UpdateProvider: UserDataProvider");
        _userDataProvider.pushNotificationDataProvider =
            pushNotificationDataProvider;
        return _userDataProvider;
      }),
  ChangeNotifierProxyProvider<UserDataProvider, CardsDataProvider>(
      create: (_) {
        print("CreateProvider: CardsDataProvider");
        var cardsDataProvider = CardsDataProvider();
        return cardsDataProvider;
      },
      lazy: false,
      update: (_, userDataProvider, cardsDataProvider) {
        print("UpdateProvider: CardsDataProvider");
        cardsDataProvider
          ..loadSavedData().then((value) {
            cardsDataProvider.updateAvailableCards(
                userDataProvider.authenticationModel.ucsdaffiliation);
            if (userDataProvider.isLoggedIn &&
                (userDataProvider.userProfileModel.classifications?.student ??
                    false)) {
              cardsDataProvider.activateStudentCards();
            } else {
              cardsDataProvider.deactivateStudentCards();
            }

            if (userDataProvider.isLoggedIn &&
                (userDataProvider.userProfileModel.classifications?.staff ??
                    false)) {
              cardsDataProvider.activateStaffCards();
            } else {
              cardsDataProvider.deactivateStaffCards();
            }
          });
        return cardsDataProvider;
      }),
  ChangeNotifierProxyProvider<UserDataProvider, ClassScheduleDataProvider>(
      create: (_) {
    print("CreateProvider: ClassScheduleDataProvider");
    var classDataProvider = ClassScheduleDataProvider();
    return classDataProvider;
  }, update: (_, userDataProvider, classScheduleDataProvider) {
    print("UpdateProvider: ClassScheduleDataProvider");
    classScheduleDataProvider.userDataProvider = userDataProvider;
    if (userDataProvider.isLoggedIn && !classScheduleDataProvider.isLoading) {
      classScheduleDataProvider.fetchData();
    }
    return classScheduleDataProvider;
  }),
  ChangeNotifierProxyProvider2<Coordinates, UserDataProvider, WayfindingProvider>(
      create: (_) {
        print("CreateProvider: AdvancedWayfindingSingleton");
        var proximityAwarenessSingleton = WayfindingProvider();
        return proximityAwarenessSingleton;
      }, update: (_, coordinates, userDataProvider, proximityAwarenessSingleton) {
    print("UpdateProvider: AdvancedWayfindingSingleton");
    proximityAwarenessSingleton.coordinates = coordinates;
    proximityAwarenessSingleton.userProvider = userDataProvider;
    return proximityAwarenessSingleton;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, StudentIdDataProvider>(
      create: (_) {
    print("CreateProvider: StudentIdDataProvider");
    var studentIdDataProvider = StudentIdDataProvider();
    return studentIdDataProvider;
  }, update: (_, userDataProvider, studentIdDataProvider) {
    print("UpdateProvider: StudentIdDataProvider");
    studentIdDataProvider.userDataProvider = userDataProvider;
    //Verify that the user is logged in
    if (userDataProvider.isLoggedIn && !studentIdDataProvider.isLoading) {
      studentIdDataProvider.fetchData();
    }
    return studentIdDataProvider;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, EmployeeIdDataProvider>(
      create: (_) {
    print("CreateProvider: EmployeeIdDataProvider");
    var employeeIdDataProvider = EmployeeIdDataProvider();
    return employeeIdDataProvider;
  }, update: (_, userDataProvider, employeeIdDataProvider) {
    print("UpdateProvider: EmployeeIdDataProvider");
    employeeIdDataProvider.userDataProvider = userDataProvider;
    //Verify that the user is logged in
    if (userDataProvider.isLoggedIn && !employeeIdDataProvider.isLoading) {
      employeeIdDataProvider.fetchData();
    }
    return employeeIdDataProvider;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, SurveyDataProvider>(
      create: (_) {
    print("CreateProvider: SurveyDataProvider");
    var surveyDataProvider = SurveyDataProvider();
    surveyDataProvider.fetchSurvey();
    return surveyDataProvider;
  }, update: (_, userDataProvider, surveyDataProvider) {
    print("UpdateProvider: SurveyDataProvider");
    surveyDataProvider.userDataProvider = userDataProvider;
    return surveyDataProvider;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, ScannerMessageDataProvider>(
      create: (_) {
        print("CreateProvider: ScannerMessageDataProvider");
        var scannerMessageDataProvider = ScannerMessageDataProvider();
        return scannerMessageDataProvider;
      }, update: (_, userDataProvider, scannerMessageDataProvider) {
      print("UpdateProvider: ScannerMessageDataProvider");
      scannerMessageDataProvider.userDataProvider = userDataProvider;
      //Verify that the user is logged in
      if (userDataProvider.isLoggedIn && !scannerMessageDataProvider.isLoading) {
        scannerMessageDataProvider.fetchData();
      }
      return scannerMessageDataProvider;
    }
  ),
  ChangeNotifierProxyProvider<UserDataProvider, AvailabilityDataProvider>(
      create: (_) {
    print("CreateProvider: AvailabilityDataProvider");
    var availabilityDataProvider = AvailabilityDataProvider();
    availabilityDataProvider.fetchAvailability();
    return availabilityDataProvider;
  }, update: (_, userDataProvider, availabilityDataProvider) {
    print("UpdateProvider: AvailabilityDataProvider");
    availabilityDataProvider.userDataProvider = userDataProvider;
    return availabilityDataProvider;
  }),
  ChangeNotifierProxyProvider2<Coordinates, UserDataProvider,
      ShuttleDataProvider>(create: (_) {
    var shuttleDataProvider = ShuttleDataProvider();
    return shuttleDataProvider;
  }, update: (_, coordinates, userDataProvider, shuttleDataProvider) {
    print("UpdateProvider: shuttleDataProvider");
    shuttleDataProvider.userCoords = coordinates;
    shuttleDataProvider.userDataProvider = userDataProvider;
    shuttleDataProvider.fetchStops(true);
    return shuttleDataProvider;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, ParkingDataProvider>(
      create: (_) {
    print("CreateProvider: ParkingDataProvider");
    var parkingDataProvider = ParkingDataProvider();
    return parkingDataProvider;
  }, update: (_, userDataProvider, parkingDataProvider) {
    print("UpdateProvider: ParkingDataProvider");
    parkingDataProvider.userDataProvider = userDataProvider;
    parkingDataProvider.fetchParkingData();
    return parkingDataProvider;
  }),
  ChangeNotifierProxyProvider<UserDataProvider, MessagesDataProvider>(
    create: (_) {
      print("CreateProvider: MessagesDataProvider");
      var messageDataProvider = MessagesDataProvider();
      return messageDataProvider;
    },
    lazy: false,
    update: (_, userDataProvider, messageDataProvider) {
      print("UpdateProvider: MessagesDataProvider");
      messageDataProvider.userDataProvider = userDataProvider;
      messageDataProvider.fetchMessages(true);
      return messageDataProvider;
    },
  ),
  ChangeNotifierProxyProvider<MessagesDataProvider, FreeFoodDataProvider>(
    create: (_) {
      print("CreateProvider: FreeFoodDataProvider");
      var freefoodDataProvider = FreeFoodDataProvider();
      freefoodDataProvider.loadRegisteredEvents();
      return freefoodDataProvider;
    },
    update: (_, messageDataProvider, freefoodDataProvider) {
      print("UpdateProvider: FreeFoodDataProvider");
      freefoodDataProvider.messageDataProvider = messageDataProvider;
      freefoodDataProvider.parseMessages();
      return freefoodDataProvider;
    },
  ),
  ChangeNotifierProxyProvider<UserDataProvider, ScannerDataProvider>(
    create: (_) {
      var _scannerDataProvider = ScannerDataProvider();
      _scannerDataProvider.initState();
      _scannerDataProvider.setDefaultStates();
      return _scannerDataProvider;
    },
    update: (_, _userDataProvider, scannerDataProvider) {
      scannerDataProvider.userDataProvider = _userDataProvider;
      scannerDataProvider.initState();
      scannerDataProvider.setDefaultStates();
      return scannerDataProvider;
    },
    lazy: false,
  )
];
List<SingleChildWidget> uiConsumableProviders = [];
