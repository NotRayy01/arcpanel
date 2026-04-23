@extends('layouts.admin')

@section('title')
    Plugin Marketplace
@endsection

@section('content-header')
    <h1>Plugin Marketplace<small>Install and manage ArcPanel plugins.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Plugin Marketplace</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-xs-12">
        @if(session('success'))
            <div class="alert alert-success">{{ session('success') }}</div>
        @endif
        @if(session('error'))
            <div class="alert alert-danger">{{ session('error') }}</div>
        @endif

        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Available Plugins</h3>
            </div>
            <div class="box-body">
                @if(empty($availablePlugins))
                    <p>No plugins available in the registry.</p>
                @else
                    <div class="row">
                        @foreach($availablePlugins as $plugin)
                            <div class="col-md-4">
                                <div class="box box-widget">
                                    <div class="box-header">
                                        <h4>{{ $plugin['name'] }}</h4>
                                    </div>
                                    <div class="box-body">
                                        <p>{{ $plugin['description'] ?? 'No description' }}</p>
                                        <p><strong>Version:</strong> {{ $plugin['version'] ?? 'N/A' }}</p>
                                        @if(in_array($plugin['name'], array_column($installedPlugins, 'name')))
                                            <span class="label label-success">Installed</span>
                                        @else
                                            <form method="POST" action="{{ route('admin.arc.plugins.install') }}" style="display:inline;">
                                                @csrf
                                                <input type="hidden" name="name" value="{{ $plugin['name'] }}">
                                                <button type="submit" class="btn btn-primary btn-sm">Install</button>
                                            </form>
                                        @endif
                                    </div>
                                </div>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>
        </div>

        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Installed Plugins</h3>
            </div>
            <div class="box-body">
                @if(empty($installedPlugins))
                    <p>No plugins installed.</p>
                @else
                    <table class="table table-striped">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Version</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            @foreach($installedPlugins as $plugin)
                                <tr>
                                    <td>{{ $plugin['name'] }}</td>
                                    <td>{{ $plugin['version'] }}</td>
                                    <td>
                                        @if($plugin['enabled'])
                                            <span class="label label-success">Enabled</span>
                                        @else
                                            <span class="label label-default">Disabled</span>
                                        @endif
                                    </td>
                                    <td>
                                        @if($plugin['enabled'])
                                            <form method="POST" action="{{ route('admin.arc.plugins.disable') }}" style="display:inline;">
                                                @csrf
                                                <input type="hidden" name="name" value="{{ $plugin['name'] }}">
                                                <button type="submit" class="btn btn-warning btn-sm">Disable</button>
                                            </form>
                                        @else
                                            <form method="POST" action="{{ route('admin.arc.plugins.enable') }}" style="display:inline;">
                                                @csrf
                                                <input type="hidden" name="name" value="{{ $plugin['name'] }}">
                                                <button type="submit" class="btn btn-success btn-sm">Enable</button>
                                            </form>
                                        @endif
                                    </td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                @endif
            </div>
        </div>
    </div>
</div>
@endsection