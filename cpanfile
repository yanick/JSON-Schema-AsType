# This file is generated by Dist::Zilla::Plugin::CPANFile v6.030
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Clone" => "0";
requires "JSON" => "0";
requires "LWP::Simple" => "0";
requires "List::AllUtils" => "0";
requires "List::MoreUtils" => "0";
requires "List::Util" => "0";
requires "Moose" => "0";
requires "Moose::Role" => "0";
requires "Moose::Util" => "0";
requires "MooseX::ClassAttribute" => "0";
requires "MooseX::MungeHas" => "0";
requires "Path::Tiny" => "0.062";
requires "Scalar::Util" => "0";
requires "Type::Library" => "0";
requires "Type::Tiny" => "0";
requires "Type::Tiny::Class" => "0";
requires "Type::Utils" => "0";
requires "Types::Standard" => "0";
requires "URI" => "0";
requires "perl" => "v5.14.0";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "Exporter" => "0";
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Path::Tiny" => "0.062";
  requires "Test::Deep" => "0";
  requires "Test::Exception" => "0";
  requires "Test::More" => "0";
  requires "lib" => "0";
  requires "parent" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "2.120900";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::More" => "0.96";
  requires "Test::Vars" => "0";
};
