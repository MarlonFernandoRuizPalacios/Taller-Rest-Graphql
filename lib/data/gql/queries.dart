const patientsQuery = r'''
  query Patients($search:String,$limit:Int=20,$offset:Int=0){
    patients(search:$search, limit:$limit, offset:$offset){
      id name documentId age sex phone severity { score level }
    }
  }
''';

const distQuery = r'''
  query Dist {
    severityDistribution { level count }
    conditionsHistogram { code count }
  }
''';

const criticalQuery = r'''
  query Criticos($limit:Int=10,$offset:Int=0){
    criticalPatients(limit:$limit, offset:$offset){
      id name severity { score level }
    }
  }
''';
