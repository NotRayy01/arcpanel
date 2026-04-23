@extends('layouts.admin')

@section('title')
    Theme Settings
@endsection

@section('content-header')
    <h1>Theme Settings<small>Customize the appearance of ArcPanel.</small></h1>
    <ol class="breadcrumb">
        <li><a href="{{ route('admin.index') }}">Admin</a></li>
        <li class="active">Theme Settings</li>
    </ol>
@endsection

@section('content')
<div class="row">
    <div class="col-md-8">
        <div class="box box-primary">
            <div class="box-header with-border">
                <h3 class="box-title">Theme Configuration</h3>
            </div>
            <form method="POST" action="{{ route('admin.arc.themes.update') }}">
                @csrf
                @method('PATCH')
                <div class="box-body">
                    <div class="form-group">
                        <label for="primary_color">Primary Color</label>
                        <input type="color" class="form-control" id="primary_color" name="primary_color" value="{{ $theme->config['primary_color'] }}">
                    </div>
                    <div class="form-group">
                        <label for="background">Background Image URL</label>
                        <input type="url" class="form-control" id="background" name="background" value="{{ $theme->config['background'] }}" placeholder="https://example.com/image.jpg">
                    </div>
                    <div class="form-group">
                        <label for="button_style">Button Style</label>
                        <select class="form-control" id="button_style" name="button_style">
                            <option value="rounded" {{ $theme->config['button_style'] == 'rounded' ? 'selected' : '' }}>Rounded</option>
                            <option value="square" {{ $theme->config['button_style'] == 'square' ? 'selected' : '' }}>Square</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <div class="checkbox">
                            <label>
                                <input type="checkbox" name="animations" value="1" {{ $theme->config['animations'] ? 'checked' : '' }}>
                                Enable Animations
                            </label>
                        </div>
                    </div>
                </div>
                <div class="box-footer">
                    <button type="submit" class="btn btn-primary">Save Changes</button>
                </div>
            </form>
        </div>
    </div>
</div>
@endsection