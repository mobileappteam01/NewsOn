import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';

part 'sample_event.dart';
part 'sample_state.dart';

class SampleBloc extends Bloc<SampleEvent, SampleState> {
  SampleBloc() : super(SampleInitial()) {
    on<SampleEvent>((event, emit) {});
  }
}
